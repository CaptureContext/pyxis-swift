#if canImport(UIKit) && canImport(XCTest)
import Foundation
import UIKit
import XCTest
import PyxisModel
import PyxisRecording
import PyxisCore
import AsyncXCUIAutomation

@MainActor
public final class PyxisRecorder {
	private let testCase: XCTestCase
	private let screenshotSource: PyxisScreenshotSource
	private let session: PyxisRecordingSession
	private var isFinished: Bool { session.isFinished }
	private var isRecording: Bool
	/// The recorded application, available to app-specific recorder extensions.
	public let app: XCUIApplication
	public var document: PyxisMapDocument { session.document }

	public convenience init(
		testCase: XCTestCase,
		app: XCUIApplication,
		configuration: PyxisRecordingConfiguration,
		report: PyxisBootstrapReport = .init(variants: [:])
	) {
		self.init(
			testCase: testCase,
			app: app,
			project: configuration.project,
			run: configuration.run,
			domains: configuration.domains,
			profile: configuration.profile,
			journeyID: configuration.journeyID ?? testCase.name,
			title: configuration.title ?? testCase.name,
			attempt: configuration.attempt,
			report: report,
			screenshotSource: configuration.screenshotSource,
			recordingKey: configuration.recordingKey
		)
	}

	public init(
		testCase: XCTestCase,
		app: XCUIApplication,
		project: PyxisProject,
		run: PyxisRunMetadata,
		domains: [PyxisDomain],
		profile: PyxisProfile,
		journeyID: String,
		title: String,
		attempt: Int = 0,
		report: PyxisBootstrapReport = .init(variants: [:]),
		screenshotSource: PyxisScreenshotSource = .application,
		recordingKey: String? = nil
	) {
		self.testCase = testCase
		self.screenshotSource = screenshotSource
		self.app = app
		self.isRecording = false
		self.session = .init(
			configuration: .init(project: project, run: run, domains: domains, profile: profile),
			recordingKey: recordingKey,
			journeyID: journeyID,
			title: title,
			testName: testCase.name,
			producer: .init(framework: "xctest", captureMethod: screenshotSource == .application ? "application" : "screen"),
			executionID: "\(attempt)-\(UUID().uuidString)",
			report: report,
			attach: { data, name in
				let attachment: XCTAttachment = .init(data: data, uniformTypeIdentifier: name.hasSuffix(".png") ? "public.png" : "public.json")
				attachment.name = name
				attachment.lifetime = .keepAlways
				testCase.add(attachment)
			}
		)

		testCase.addTeardownBlock { [self] in
			try await MainActor.run {
				guard !self.isFinished else { return }

				let run = self.testCase.testRun
				let status: PyxisObservationStatus
				if let run, run.totalFailureCount > 0 {
					status = .failed
				} else if let run, run.skipCount == 0 {
					status = .passed
				} else {
					status = .incomplete
				}

				try self.finish(status: status)
			}
		}
	}

	/// Optional launch lifecycle shared with PyxisTestCase. Use configureLaunch for manual launches.
	public func launch(
		configure: @MainActor (XCUIApplication) async throws -> Void = { _ in },
		ready: @MainActor () async throws -> Void = {},
		readReport: @MainActor () async throws -> PyxisBootstrapReport? = { nil }
	) async throws {
		try beginOperation()
		defer { isRecording = false }

		do {
			try Task.checkCancellation()
			try await configure(app)
			try Task.checkCancellation()
			try configureLaunchEnvironment()
			app.launch()
			try await ready()
			if let report = try await readReport() {
				try session.updateReport(report)
			}
			try Task.checkCancellation()
		} catch {
			try session.fail(error)
			throw error
		}
	}

	/// Configures the owned application from this recorder's profile without launching it.
	public func configureLaunch() throws {
		guard !isRecording else { throw PyxisRecorderError.recordingInProgress }
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }
		try configureLaunchEnvironment()
	}

	public func updateReport(_ report: PyxisBootstrapReport) throws {
		guard !isRecording else { throw PyxisRecorderError.recordingInProgress }
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }
		try session.updateReport(report)
	}

	/// Consumer owns readiness; overlapping recording operations are rejected.
	public func capture(
		_ state: PyxisState,
		ready: () throws -> Void = {}
	) throws {
		try beginOperation()
		defer { isRecording = false }
		try performCapture(state, ready: ready)
	}

	public func transition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		key: String? = nil,
		ready: () throws -> Void = {},
		perform: () throws -> Void
	) throws {
		try beginOperation()
		defer { isRecording = false }
		try performTransition(
			from: source,
			to: destination,
			action: action,
			kind: kind,
			key: key,
			ready: ready,
			perform: perform
		)
	}

	public func capture(
		_ state: PyxisState,
		ready: @MainActor () async throws -> Void = {}
	) async throws {
		try beginOperation()
		defer { isRecording = false }
		try await performCapture(state, ready: ready)
	}

	public func transition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		key: String? = nil,
		ready: @MainActor () async throws -> Void = {},
		perform: @MainActor () async throws -> Void
	) async throws {
		try beginOperation()
		defer { isRecording = false }
		try await performTransition(
			from: source,
			to: destination,
			action: action,
			kind: kind,
			key: key,
			ready: ready,
			perform: perform
		)
	}

	private func performCapture(
		_ state: PyxisState,
		ready: () throws -> Void = {}
	) throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		try translateRecordingError { try session.declare(state) }
		let failuresBefore = testCase.testRun?.totalFailureCount ?? 0

		do {
			try ready()
			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try recordCapture(state)
		}
		catch {
			try session.fail(error)
			throw error
		}
	}

	private func performTransition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		key: String? = nil,
		ready: () throws -> Void = {},
		perform: () throws -> Void
	) throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		let index = try translateRecordingError {
			try session.beginTransition(from: source, to: destination, action: action, kind: kind, key: key)
		}

		do {
			let failuresBefore = testCase.testRun?.totalFailureCount ?? 0
			try perform()

			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try performCapture(destination, ready: ready)

			try session.succeedTransition(index)
		}
		catch {
			try failTransition(index, error: error)
			throw error
		}
	}

	public func finish(
		status: PyxisObservationStatus = .passed,
		failure: String? = nil
	) throws {
		guard !isFinished else { return }
		guard !isRecording else { throw PyxisRecorderError.recordingInProgress }

		let hasFailure = document.transitions.contains { $0.status == .failed }
		|| (testCase.testRun?.totalFailureCount ?? 0) > 0
		|| document.observations[0].status == .failed

		try session.finish(status: hasFailure ? .failed : status, failure: failure)
	}

	public func require(
		_ element: XCUIElement,
		timeout: TimeInterval = 5
	) throws {
		guard element.exists || element.waitForExistence(timeout: timeout)
		else { throw PyxisRecorderError.readinessTimedOut(element.description) }
	}

	private func performCapture(
		_ state: PyxisState,
		ready: @MainActor () async throws -> Void
	) async throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		try translateRecordingError { try session.declare(state) }
		let failuresBefore = testCase.testRun?.totalFailureCount ?? 0

		do {
			try Task.checkCancellation()
			try await ready()
			try Task.checkCancellation()
			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try recordCapture(state)
		}
		catch {
			try session.fail(error)
			throw error
		}
	}

	private func performTransition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		key: String? = nil,
		ready: @MainActor () async throws -> Void,
		perform: @MainActor () async throws -> Void
	) async throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		let index = try translateRecordingError {
			try session.beginTransition(from: source, to: destination, action: action, kind: kind, key: key)
		}

		do {
			let failuresBefore = testCase.testRun?.totalFailureCount ?? 0
			try Task.checkCancellation()
			try await perform()
			try Task.checkCancellation()

			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try await performCapture(destination, ready: ready)

			try session.succeedTransition(index)
		}
		catch {
			try failTransition(index, error: error)
			throw error
		}
	}

	public func require(
		_ element: XCUIElement,
		timeout: Duration = .seconds(5)
	) async throws {
		guard try await element.waitForExistence(timeout: timeout)
		else { throw PyxisRecorderError.readinessTimedOut(element.description) }
	}

	private func configureLaunchEnvironment() throws {
		app.launchEnvironment[pyxisEnvironmentKey] = try BootstrapRequest(
			requested: document.profiles[0].requested
		).encoded()
	}

	private func beginOperation() throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }
		guard !isRecording else { throw PyxisRecorderError.recordingInProgress }
		isRecording = true
	}

	private func takeScreenshot() throws -> XCUIScreenshot {
		switch screenshotSource {
		case .application: return app.screenshot()
		case .screen: return XCUIScreen.main.screenshot()
		case let .display(index):
			let screens = XCUIScreen.screens
			guard screens.indices.contains(index)
			else { throw PyxisRecorderError.unavailableScreen(index: index, available: screens.count) }
			return screens[index].screenshot()
		}
	}

	private func recordCapture(_ state: PyxisState) throws {
		let screenshot: XCUIScreenshot = try takeScreenshot()
		let image: UIImage = screenshot.image
		try session.capture(
			state,
			png: screenshot.pngRepresentation,
			width: image.cgImage?.width ?? Int(image.size.width * image.scale),
			height: image.cgImage?.height ?? Int(image.size.height * image.scale)
		)
	}

	private func failTransition(_ index: Int, error: any Error) throws {
		try session.fail(error, transition: index)

		let hierarchy = XCTAttachment(string: app.debugDescription)
		hierarchy.name = "pyxis-failure-hierarchy"
		hierarchy.lifetime = .keepAlways
		testCase.add(hierarchy)

		let screenshot: XCTAttachment
		do {
			screenshot = try XCTAttachment(screenshot: takeScreenshot())
		}
		catch {
			screenshot = XCTAttachment(string: "Screenshot unavailable: \(error)")
		}
		screenshot.name = "pyxis-failure-diagnostic"
		screenshot.lifetime = .keepAlways
		testCase.add(screenshot)
	}

	private func translateRecordingError<Value>(_ operation: () throws -> Value) throws -> Value {
		do {
			return try operation()
		} catch PyxisRecordingError.sourceNotCaptured(let id) {
			throw PyxisRecorderError.sourceNotCaptured(id)
		} catch PyxisRecordingError.conflictingState(let id) {
			throw PyxisRecorderError.conflictingState(id)
		} catch PyxisRecordingError.alreadyFinished {
			throw PyxisRecorderError.alreadyFinished
		}
	}
}
#endif
