#if canImport(UIKit) && canImport(XCTest)
import XCTest
import PyxisCore

/// Optional XCTest lifecycle integration; existing test classes can use PyxisRecorder directly.
open class PyxisTestCase: XCTestCase {
	@MainActor
	private var _app: XCUIApplication?

	@MainActor
	private var _recorder: PyxisRecorder?

	open override func setUp() async throws {
		try await super.setUp()
		try await self.prepareRecording()
	}

	/// Override in an app-owned base class or each concrete test class.
	@MainActor
	open var recordingConfiguration: PyxisRecordingConfiguration? { nil }

	/// Override when configuration comes from input that can fail, such as run metadata.
	@MainActor
	open func makeRecordingConfiguration() throws -> PyxisRecordingConfiguration {
		guard let configuration = recordingConfiguration
		else { throw PyxisRecorderError.missingTestConfiguration }
		return configuration
	}

	/// Available after successful setup. Override makeApplication to select another app.
	@MainActor
	public final var app: XCUIApplication {
		guard let app = _app else { preconditionFailure("Pyxis test setup has not created the app") }
		return app
	}

	@MainActor
	public final var recorder: PyxisRecorder {
		guard let recorder = _recorder else { preconditionFailure("Pyxis test setup has not created the recorder") }
		return recorder
	}

	@MainActor
	open func makeApplication() -> XCUIApplication { XCUIApplication() }

	/// Runs before Pyxis configures the app's launch environment and launches it.
	@MainActor
	open func configureApplication(_ app: XCUIApplication) async throws {}

	@MainActor
	open func waitUntilReady() async throws {}

	/// Override for the app's report transport. No diagnostic element is assumed.
	@MainActor
	open func readBootstrapReport() async throws -> PyxisBootstrapReport? { nil }

	@MainActor
	private func prepareRecording() async throws {
		let configuration = try makeRecordingConfiguration()

		let app = makeApplication()
		_app = app
		// Teardown blocks run in reverse order: finalize the recorder before terminating the app.
		addTeardownBlock {
			await MainActor.run { app.terminate() }
		}
		let recorder = PyxisRecorder(
			testCase: self,
			app: app,
			configuration: configuration
		)
		_recorder = recorder

		try await recorder.launch(
			configure: { try await self.configureApplication($0) },
			ready: { try await self.waitUntilReady() },
			readReport: { try await self.readBootstrapReport() }
		)
	}
}
#endif
