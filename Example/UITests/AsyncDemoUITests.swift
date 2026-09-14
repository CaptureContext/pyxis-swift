import ExampleTesting
import XCTest

internal final class AsyncDemoUITests: PyxisTestCase {
	@MainActor
	internal override func makeRecordingConfiguration() throws -> PyxisRecordingConfiguration {
		try .example(
			profile: .init(colorScheme: .light),
			journey: .dedicatedAsync
		)
	}

	@MainActor
	internal override func configureApplication(_ app: XCUIApplication) async throws {
		try recorder.configureExampleDevice()
		app.launchEnvironment[.asyncProbe] = ExampleInput.preservedProbe
		await Task.yield()
	}

	@MainActor
	internal override func waitUntilReady() async throws {
		try await recorder.require(app.staticTexts[.ready(.home)])
	}

	@MainActor
	internal override func readBootstrapReport() async throws -> PyxisBootstrapReport? {
		let element = app.staticTexts[.report]
		try await recorder.require(element)
		return try PyxisBootstrapReport(encoded: XCTUnwrap(element.value as? String))
	}

	@MainActor
	internal func testAsyncJourney() async throws {
		XCTAssertEqual(app.launchEnvironment[.asyncProbe], ExampleInput.preservedProbe)
		let foreground = try await app.wait(for: .runningForeground, timeout: .seconds(5))
		XCTAssertTrue(foreground)
		let missing = try await app.buttons[.missing].waitForExistence(timeout: .zero)
		XCTAssertFalse(missing)
		let absent = try await app.buttons[.missing].waitForNonExistence(timeout: .zero)
		XCTAssertTrue(absent)

		try await recorder.capture(.home)
		try await recorder.transition(
			from: .home,
			to: .detail,
			action: "Open Detail asynchronously",
			ready: { try await self.recorder.require(self.app.staticTexts[.ready(.detail)]) },
			perform: {
				let button = self.app.buttons[.openDetail]
				let hittable = try await button.wait(for: \.isHittable, toEqual: true, timeout: .seconds(5))
				XCTAssertTrue(hittable)
				button.tap()
			}
		)
		// No explicit finish: export must contain a passed observation from automatic teardown.
	}

	@MainActor
	internal func testAsyncThrownFailure() async throws {
		guard ProcessInfo.processInfo.environment[.verifyAsyncFailure] == ExampleInput.enabledFlag
		else { throw XCTSkip("Opt-in check that a thrown async test finalizes as failed") }
		try await recorder.capture(.home)
		await Task.yield()
		throw PyxisRecorderError.readinessTimedOut("Intentional async test failure")
	}

	@MainActor
	internal func testCancellationAndOverlappingOperations() async throws {
		try await recorder.capture(.home)
		var started = false
		let pending = Task { @MainActor in
			try await self.recorder.transition(
				from: .home,
				to: .detail,
				action: "Cancelled transition",
				perform: {
					started = true
					try await self.recorder.require(self.app.buttons[.missing], timeout: .seconds(60))
				}
			)
		}
		while !started { await Task.yield() }
		do {
			try await recorder.capture(.home)
			XCTFail("Overlapping capture must be rejected")
		} catch PyxisRecorderError.recordingInProgress {}
		XCTAssertThrowsError(try recorder.finish())
		XCTAssertThrowsError(try recorder.configureLaunch())
		pending.cancel()
		do {
			try await pending.value
			XCTFail("The operation must throw on cancellation")
		} catch is CancellationError {}
		XCTAssertEqual(recorder.document.observations[0].status, .failed)
		XCTAssertEqual(recorder.document.transitions[0].status, .failed)
		// A caught cancellation is a failed recording even though XCTest itself passes.
	}
}
