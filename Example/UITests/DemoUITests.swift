import ExampleTesting
import XCTest

internal final class DemoUITests: XCTestCase {
	private enum DemoFailure: Error { case unavailable }

	@MainActor
	internal func testAsyncRecordingInExistingTest() async throws {
		let (app, recorder) = try launch(colorScheme: .light, journey: .existingAsyncTest)
		try await recorder.capture(.home) {
			try await recorder.require(app.staticTexts[.ready(.home)])
		}
		XCTAssertTrue(app.buttons[.openDetail].exists)
		XCTAssertTrue(app.buttons[.openSettings].exists)
		// Existing XCTestCase subclasses receive automatic finalization too.
	}

	@MainActor
	internal func testLightTour() throws {
		try tour(colorScheme: .light)
	}

	@MainActor
	internal func testDarkLargeTypeTour() throws {
		try tour(colorScheme: .dark, contentSize: .xxxLarge)
	}

	@MainActor
	internal func testFailureFragment() throws {
		let (app, recorder) = try launch(
			colorScheme: .light,
			journey: .failure
		)

		try recorder.capture(.home) {
			try recorder.require(app.staticTexts[.ready(.home)])
		}

		do {
			try recorder.transition(
				from: .home,
				to: .detail,
				action: "Demonstrate failed transition",
				perform: { throw DemoFailure.unavailable }
			)

			XCTFail("The deliberately failing transition should throw")
		}
		catch DemoFailure.unavailable {
			try recorder.finish(
				status: .failed,
				failure: "Intentional failure fixture; XCTest itself passes."
			)
		}
	}

	@MainActor
	internal func testNonthrowingAssertionFailure() throws {
		guard ProcessInfo.processInfo.environment[.verifyAssertionFailure] == ExampleInput.enabledFlag
		else { throw XCTSkip("Opt-in verification of a failing XCTest run and partial export.") }

		continueAfterFailure = true
		let (app, recorder) = try launch(
			colorScheme: .light,
			journey: .assertionFailure
		)

		try recorder.capture(.home) {
			try recorder.require(app.staticTexts[.ready(.home)])
		}

		do {
			try recorder.transition(
				from: .home,
				to: .detail,
				action: "Nonthrowing assertion failure",
				perform:{
					XCTFail("Intentional nonthrowing assertion failure for export verification")
				}
			)
			XCTFail("Recorder must reject the failed action")
		}
		catch PyxisRecorderError.recordedXCTestFailure {
			try recorder.finish(status: .passed)
			XCTAssertEqual(recorder.document.observations[0].status, .failed)
			XCTAssertEqual(recorder.document.transitions[0].status, .failed)
		}
	}

	@MainActor
	private func tour(
		colorScheme: ExampleProfile.ColorScheme,
		direction: ExampleProfile.LayoutDirection = .ltr,
		contentSize: ExampleProfile.ContentSize = .large
	) throws {
		let (app, recorder) = try launch(
			colorScheme: colorScheme,
			direction: direction,
			contentSize: contentSize,
			journey: .tour
		)

		try recorder.capture(.home) {
			try recorder.require(
				app.staticTexts[.ready(.home)]
			)
		}

		try recorder.transition(
			from: .home,
			to: .detail,
			action: "Open Detail",
			ready: { try recorder.require(app.staticTexts[.ready(.detail)]) },
			perform: { try ExampleNavigation(app: app).tap(.openDetail) }
		)

		try recorder.transition(
			from: .detail,
			to: .home,
			action: "Back to Home",
			ready: { try recorder.require(app.staticTexts[.ready(.home)]) },
			perform: { app.navigationBars.buttons.element(boundBy: 0).tap() }
		)

		try recorder.transition(
			from: .home,
			to: .settings,
			action: "Open Settings",
			ready: { try recorder.require(app.staticTexts[.ready(.settings)]) },
			perform: { try ExampleNavigation(app: app).tap(.openSettings) }
		)

		try recorder.finish()
	}

	@MainActor
	private func launch(
		colorScheme: ExampleProfile.ColorScheme = .dark,
		direction: ExampleProfile.LayoutDirection = .ltr,
		contentSize: ExampleProfile.ContentSize = .large,
		journey: ExampleJourney
	) throws -> (XCUIApplication, PyxisRecorder) {
		let app = XCUIApplication()

		let recorder: PyxisRecorder = try .init(
			testCase: self,
			app: app,
			configuration: .example(
				profile: .init(
					colorScheme: colorScheme,
					direction: direction,
					contentSize: contentSize
				),
				journey: journey
			)
		)
		addTeardownBlock { @MainActor in app.terminate() }

		try recorder.configureExampleDevice()
		try recorder.configureLaunch()
		app.launch()

		let reportElement = app.staticTexts[.report]
		try recorder.require(reportElement)
		try recorder.updateReport(PyxisBootstrapReport(encoded:
			XCTUnwrap(reportElement.value as? String)
		))

		return (app, recorder)
	}
}
