#if canImport(UIKit) && canImport(XCTest)
import Foundation
import UIKit
import XCTest
import PyxisModel
import PyxisProcessing
import PyxisCore
import AsyncXCUIAutomation

@MainActor
public final class PyxisRecorder {
	private let testCase: XCTestCase
	private let screenshotSource: PyxisScreenshotSource
	private var sequence: Int
	private var revision: Int
	private var isFinished: Bool
	private var isRecording: Bool
	/// The recorded application, available to app-specific recorder extensions.
	public let app: XCUIApplication
	public private(set) var document: PyxisMapDocument

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
			screenshotSource: configuration.screenshotSource
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
		screenshotSource: PyxisScreenshotSource = .application
	) {
		self.testCase = testCase
		self.screenshotSource = screenshotSource
		self.app = app
		self.sequence = 0
		self.revision = 0
		self.isFinished = false
		self.isRecording = false

		let observationID = StableID.observation(
			projectID: project.id,
			runID: run.id,
			journeyID: journeyID,
			testName: testCase.name,
			profileID: profile.id,
			attempt: attempt
		)

		self.document = .init(
			format: .fragment,
			project: project,
			run: run,
			domains: domains,
			profiles: [profile],
			observations: [
				.init(
					id: observationID,
					journeyID: journeyID,
					title: title,
					testName: testCase.name,
					profileID: profile.id,
					status: .incomplete,
					variants: report.covering(profile.requested).variants
				)
			]
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
				storeReport(report)
			}
			try Task.checkCancellation()
		} catch {
			document.observations[0].status = .failed
			document.observations[0].failure = String(describing: error)
			try attachFragment()
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
		storeReport(report)
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
			ready: ready,
			perform: perform
		)
	}

	private func performCapture(
		_ state: PyxisState,
		ready: () throws -> Void = {}
	) throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		try declare(state)
		let failuresBefore = testCase.testRun?.totalFailureCount ?? 0

		do {
			try ready()
			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }
		}
		catch {
			document.observations[0].status = .failed
			document.observations[0].failure = String(describing: error)
			try attachFragment()
			throw error
		}

		try recordCapture(state)
	}

	private func performTransition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		ready: () throws -> Void = {},
		perform: () throws -> Void
	) throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		let index = try beginTransition(from: source, to: destination, action: action, kind: kind)

		do {
			let failuresBefore = testCase.testRun?.totalFailureCount ?? 0
			try perform()

			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try performCapture(destination, ready: ready)

			document.transitions[index].status = .succeeded
			document.transitions[index].failure = nil

			try attachFragment()
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

		document.observations[0].status = hasFailure ? .failed : status
		document.observations[0].failure = failure ?? document.observations[0].failure

		try attachFragment()
		isFinished = true
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

		try declare(state)
		let failuresBefore = testCase.testRun?.totalFailureCount ?? 0

		do {
			try Task.checkCancellation()
			try await ready()
			try Task.checkCancellation()
			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }
		}
		catch {
			document.observations[0].status = .failed
			document.observations[0].failure = String(describing: error)
			try attachFragment()
			throw error
		}

		try recordCapture(state)
	}

	private func performTransition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String = "navigation",
		ready: @MainActor () async throws -> Void,
		perform: @MainActor () async throws -> Void
	) async throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }

		let index = try beginTransition(from: source, to: destination, action: action, kind: kind)

		do {
			let failuresBefore = testCase.testRun?.totalFailureCount ?? 0
			try Task.checkCancellation()
			try await perform()
			try Task.checkCancellation()

			guard (testCase.testRun?.totalFailureCount ?? 0) == failuresBefore
			else { throw PyxisRecorderError.recordedXCTestFailure }

			try await performCapture(destination, ready: ready)

			document.transitions[index].status = .succeeded
			document.transitions[index].failure = nil

			try attachFragment()
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

	private func storeReport(_ report: PyxisBootstrapReport) {
		document.observations[0].variants = report
			.covering(document.profiles[0].requested)
			.variants
	}

	private func beginOperation() throws {
		guard !isFinished else { throw PyxisRecorderError.alreadyFinished }
		guard !isRecording else { throw PyxisRecorderError.recordingInProgress }
		isRecording = true
	}

	private func takeScreenshot() -> XCUIScreenshot {
		switch screenshotSource {
		case .application: app.screenshot()
		case .screen: XCUIScreen.main.screenshot()
		}
	}

	private func recordCapture(_ state: PyxisState) throws {
		let screenshot = takeScreenshot()
		let data = screenshot.pngRepresentation
		let image = screenshot.image
		let observationID = document.observations[0].id

		let occurrence = document.captures
			.filter { $0.stateID.utf8.elementsEqual(state.id.utf8) }
			.count

		let id = StableID.capture(
			observationID: observationID,
			stateID: state.id,
			occurrence: occurrence
		)

		let attachment = XCTAttachment(
			data: data,
			uniformTypeIdentifier: "public.png"
		)

		attachment.name = "\(id).png"
		attachment.lifetime = .keepAlways
		testCase.add(attachment)
		document.captures.append(.init(
			id: id,
			stateID: state.id,
			observationID: observationID,
			sequence: nextSequence(),
			asset: .init(
				path: "assets/\(id).png",
				mediaType: .png,
				width: image.cgImage?.width ?? Int(image.size.width * image.scale),
				height: image.cgImage?.height ?? Int(image.size.height * image.scale)
			)
		))

		try attachFragment()
	}

	private func beginTransition(
		from source: PyxisState,
		to destination: PyxisState,
		action: String,
		kind: String
	) throws -> Int {
		guard document.captures.contains(where: { $0.stateID.utf8.elementsEqual(source.id.utf8) })
		else { throw PyxisRecorderError.sourceNotCaptured(source.id) }

		try declare(source)
		try declare(destination)

		let sequence = nextSequence()
		let index = document.transitions.count

		document.transitions.append(.init(
			id: StableID.transition(
				observationID: document.observations[0].id,
				sequence: sequence
			),
			observationID: document.observations[0].id,
			fromStateID: source.id,
			toStateID: destination.id,
			action: action,
			kind: kind,
			sequence: sequence,
			status: .failed,
			failure: "Transition did not complete."
		))

		try attachFragment()

		return index
	}

	private func failTransition(_ index: Int, error: any Error) throws {
		document.transitions[index].failure = String(describing: error)
		document.observations[0].status = .failed
		document.observations[0].failure = String(describing: error)

		let hierarchy = XCTAttachment(string: app.debugDescription)
		hierarchy.name = "pyxis-failure-hierarchy"
		hierarchy.lifetime = .keepAlways
		testCase.add(hierarchy)

		let screenshot = XCTAttachment(screenshot: takeScreenshot())
		screenshot.name = "pyxis-failure-diagnostic"
		screenshot.lifetime = .keepAlways
		testCase.add(screenshot)

		try attachFragment()
	}

	private func declare(_ state: PyxisState) throws {
		let existing = document.states.first { $0.id.utf8.elementsEqual(state.id.utf8) }

		if let existing {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.sortedKeys]

			guard try encoder.encode(existing) == encoder.encode(state)
			else { throw PyxisRecorderError.conflictingState(state.id) }
			return
		}

		document.states.append(state)
	}

	private func nextSequence() -> Int {
		defer { sequence += 1 }
		return sequence
	}

	private func attachFragment() throws {
		try PyxisValidation.validate(document)

		let attachment = try XCTAttachment(
			data: PyxisJSON.encode(document),
			uniformTypeIdentifier: "public.json"
		)

		attachment.name = "pyxis-fragment-\(document.observations[0].id)-\(revision).json"
		attachment.lifetime = .keepAlways

		testCase.add(attachment)
		revision += 1
	}
}
#endif
