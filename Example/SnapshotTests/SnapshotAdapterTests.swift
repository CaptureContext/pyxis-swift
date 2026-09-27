import Foundation
import UIKit
import Testing
import SnapshotTesting
import PyxisCore
@testable import PyxisTesting

@MainActor
@Suite(.serialized)
internal struct SnapshotAdapterTests {
	@Test
	internal func synchronousRendererCannotCompletePastItsDeadline() async throws {
		let (recorder, session) = makeRecorder()
		let strategy: Snapshotting<UIImage, UIImage> = .init(pathExtension: "png", diffing: .image, snapshot: { image in
			// Deliberately occupy the main actor, preventing the timeout task from running.
			Thread.sleep(forTimeInterval: 0.03)
			return image
		})
		await #expect(throws: PyxisSnapshotError.self) {
			try await recorder.capture(state("empty"), value: image(.red), as: strategy, timeout: .milliseconds(10))
		}
		#expect(session.document.captures.isEmpty)
		#expect(session.document.observations[0].status == .failed)
	}

	@Test
	internal func timeoutIgnoresLateCallbacks() async throws {
		let (recorder, session) = makeRecorder()
		var callback: ((UIImage) -> Void)?
		let strategy: Snapshotting<UIImage, UIImage> = .init(pathExtension: "png", diffing: .image, asyncSnapshot: { _ in
			.init { callback = $0 }
		})
		await #expect(throws: PyxisSnapshotError.self) {
			try await recorder.capture(state("empty"), value: image(.red), as: strategy, timeout: .milliseconds(10))
		}
		callback?(image(.red))
		#expect(session.document.captures.isEmpty)
		#expect(session.document.observations[0].status == .failed)
	}

	@Test
	internal func cancellationCannotEmitACapture() async throws {
		let (recorder, session) = makeRecorder()
		let task = Task { try await recorder.capture(state("empty"), value: image(.red), as: .image) }
		task.cancel()
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(session.document.captures.isEmpty)
		#expect(session.document.observations[0].status == .failed)
	}

	@Test
	internal func duplicateCallbacksAndRealStateTransitions() async throws {
		let (recorder, session) = makeRecorder()
		let strategy: Snapshotting<UIImage, UIImage> = .init(pathExtension: "png", diffing: .image, asyncSnapshot: { image in
			.init { callback in callback(image); callback(image) }
		})
		try await recorder.capture(state("empty"), value: image(.red), as: strategy)
		try await recorder.transition(from: state("empty"), to: state("filled"), action: "Change color", as: .image) { image(.blue) }
		#expect(session.document.captures.count == 2)
		#expect(session.document.transitions[0].status == .succeeded)
		try recorder.complete()
		#expect(session.document.observations[0].status == .incomplete)
	}

	@Test
	internal func recordingAndMismatchingBaselinesCannotPass() async throws {
		let directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let (recording, recorded) = makeRecorder()
		await #expect(throws: PyxisSnapshotError.self) {
			try await recording.capture(state("empty"), value: image(.red), as: .image,
				baseline: .init(directory: directory.path, name: "fixture", record: true), testName: "baseline")
		}
		#expect(recorded.document.observations[0].status == .failed)
		#expect(recorded.document.captures.count == 1)
		let (matching, _) = makeRecorder()
		try await matching.capture(state("empty"), value: image(.red), as: .image,
			baseline: .init(directory: directory.path, name: "fixture"), testName: "baseline")
		let (mismatching, mismatched) = makeRecorder()
		await #expect(throws: PyxisSnapshotError.self) {
			try await mismatching.capture(state("empty"), value: image(.blue), as: .image,
				baseline: .init(directory: directory.path, name: "fixture"), testName: "baseline")
		}
		#expect(mismatched.document.observations[0].status == .failed)
	}

	private func makeRecorder() -> (PyxisSnapshotRecorder, PyxisRecordingSession) {
		let session: PyxisRecordingSession = .init(
			configuration: .init(
				project: .init(id: "adapter-test", title: "Adapter test"), run: .init(id: "run", createdAt: Date(timeIntervalSince1970: 0)),
				domains: [.init(id: "fixture", title: "Fixture", order: 0)], profile: .init(id: "default", title: "Default", requested: [:])
			),
			recordingKey: "fixture", journeyID: "fixture", title: "Fixture", testName: "fixture",
			producer: .init(framework: "swift_testing", captureMethod: "snapshot_testing"), attach: { _, _ in }
		)
		return (.init(session: session), session)
	}

	private func state(_ id: String) -> PyxisState {
		.init(id: id, screenID: "fixture", domainID: "fixture", title: "Fixture", label: id, order: 0)
	}

	private func image(_ color: UIColor) -> UIImage {
		UIGraphicsImageRenderer(size: .init(width: 4, height: 4)).image { context in
			color.setFill()
			context.fill(.init(x: 0, y: 0, width: 4, height: 4))
		}
	}
}
