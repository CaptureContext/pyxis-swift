#if canImport(UIKit)
import Foundation
import UIKit
import Testing
import SnapshotTesting
import PyxisCore
import PyxisRecording
import PyxisModel

/// Main-actor capture of an explicitly prepared value using SnapshotTesting strategies.
@MainActor
public final class PyxisSnapshotRecorder {
	public var document: PyxisMapDocument { session.document }
	private let session: PyxisRecordingSession
	private var isRecording: Bool = false

	internal init(session: PyxisRecordingSession) {
		self.session = session
	}

	public func capture<Value>(
		_ state: PyxisState,
		value: Value,
		as strategy: Snapshotting<Value, UIImage>,
		timeout: Duration = .seconds(5),
		baseline: PyxisSnapshotBaseline? = nil,
		fileID: StaticString = #fileID,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line,
		column: UInt = #column
	) async throws {
		guard !isRecording else { throw PyxisSnapshotError.recordingInProgress }
		isRecording = true
		defer { isRecording = false }
		try await performCapture(
			state, value: value, as: strategy, timeout: timeout, baseline: baseline,
			fileID: fileID, file: file, testName: testName, line: line, column: column
		)
	}

	/// Records an edge only for an action actually performed in this observation.
	public func transition<Value>(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "state",
		key: String? = nil,
		as strategy: Snapshotting<Value, UIImage>,
		timeout: Duration = .seconds(5),
		perform: @MainActor () async throws -> Value
	) async throws {
		guard !isRecording else { throw PyxisSnapshotError.recordingInProgress }
		isRecording = true
		defer { isRecording = false }
		let index: Int = try session.beginTransition(from: source, to: destination, action: action, kind: kind, key: key)
		do {
			try Task.checkCancellation()
			let value: Value = try await perform()
			try await performCapture(destination, value: value, as: strategy, timeout: timeout)
			try session.succeedTransition(index)
		} catch {
			try session.fail(error, transition: index)
			throw error
		}
	}

	internal func complete() throws {
		guard !isRecording else { throw PyxisSnapshotError.recordingInProgress }
		try session.finish(status: .incomplete)
	}

	private func performCapture<Value>(
		_ state: PyxisState,
		value: Value,
		as strategy: Snapshotting<Value, UIImage>,
		timeout: Duration = .seconds(5),
		baseline: PyxisSnapshotBaseline? = nil,
		fileID: StaticString = #fileID,
		file: StaticString = #filePath,
		testName: String = #function,
		line: UInt = #line,
		column: UInt = #column
	) async throws {
		do {
			try session.declare(state)
			try Task.checkCancellation()
			let rendered: RenderedImage = try await render(value, as: strategy, timeout: timeout)
			try Task.checkCancellation()
			try session.capture(state, png: rendered.png, width: rendered.width, height: rendered.height)
			if let baseline {
				guard let image = UIImage(data: rendered.png) else { throw PyxisSnapshotError.invalidImage }
				let comparison: Snapshotting<UIImage, UIImage> = .init(
					pathExtension: strategy.pathExtension, diffing: strategy.diffing, snapshot: { $0 }
				)
				if let failure = verifySnapshot(
					of: image, as: comparison, named: baseline.name, record: baseline.record ? .all : .never,
					snapshotDirectory: baseline.directory, fileID: fileID, file: file,
					testName: testName, line: line, column: column
				) {
					throw PyxisSnapshotError.baseline(failure)
				}
			}
		} catch {
			try session.fail(error)
			throw error
		}
	}

	private func render<Value>(
		_ value: Value,
		as strategy: Snapshotting<Value, UIImage>,
		timeout: Duration
	) async throws -> RenderedImage {
		let pending: PendingImage = .init()
		let deadline: ContinuousClock.Instant = .now.advanced(by: timeout)
		return try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				pending.install(continuation)
				let timer: Task<Void, Never> = Task {
					do {
						try await Task.sleep(until: deadline, clock: .continuous)
						pending.complete(.failure(PyxisSnapshotError.timedOut))
					} catch {}
				}
				pending.setTimer(timer)
				strategy.snapshot(value).run { image in
					guard ContinuousClock.now < deadline else {
						pending.complete(.failure(PyxisSnapshotError.timedOut))
						return
					}
					guard let png = image.pngData(), let cgImage = image.cgImage else {
						pending.complete(.failure(PyxisSnapshotError.invalidImage))
						return
					}
					pending.complete(.success(.init(png: png, width: cgImage.width, height: cgImage.height)))
				}
			}
		} onCancel: {
			pending.complete(.failure(CancellationError()))
		}
	}
}

private struct RenderedImage: Sendable {
	let png: Data
	let width: Int
	let height: Int
}

/// Snapshot strategies may call back off the main actor, or after cancellation/timeout.
private final class PendingImage: @unchecked Sendable {
	private let lock: NSLock = .init()
	private var continuation: CheckedContinuation<RenderedImage, any Error>?
	private var result: Result<RenderedImage, any Error>?
	private var timer: Task<Void, Never>?

	func install(_ continuation: CheckedContinuation<RenderedImage, any Error>) {
		lock.lock()
		if let result {
			lock.unlock()
			continuation.resume(with: result)
		} else {
			self.continuation = continuation
			lock.unlock()
		}
	}

	func setTimer(_ timer: Task<Void, Never>) {
		lock.lock()
		if result != nil {
			lock.unlock()
			timer.cancel()
		} else {
			self.timer = timer
			lock.unlock()
		}
	}

	func complete(_ result: Result<RenderedImage, any Error>) {
		lock.lock()
		guard self.result == nil else { lock.unlock(); return }
		self.result = result
		let continuation = self.continuation
		let timer = self.timer
		self.continuation = nil
		self.timer = nil
		lock.unlock()
		timer?.cancel()
		continuation?.resume(with: result)
	}
}
#endif
