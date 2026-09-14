import ExampleTesting
import XCTest

@MainActor
internal final class MatrixUITests: XCTestCase {
	internal func testNotesJourney() async throws {
		let recorder: PyxisRecorder = try await launch(journey: .writeNote)
		try await recorder.capture(.home)
		try await navigate(recorder, from: .home, to: .detail, button: .openDetail, action: "Read a note")
		try await recorder.transition(
			from: .detail, to: .home, action: "Back to Notes", kind: "back",
			ready: { try await recorder.requireExampleState(.home) },
			perform: { recorder.app.navigationBars.buttons.element(boundBy: 0).tap() }
		)
		try await navigate(recorder, from: .home, to: .notebooks, button: .openNotebooks, action: "Browse notebooks")
		try await navigate(recorder, from: .notebooks, to: .notebooksEmpty, button: .clearNotebook, action: "Clear notebook")
		try await navigate(recorder, from: .notebooksEmpty, to: .editorEmpty, button: .openEditor, action: "Draft a note")
		try await recorder.transition(
			from: .editorEmpty, to: .editorKeyboard, action: "Write a title",
			ready: { try await recorder.requireExampleState(.editorKeyboard) },
			perform: {
				let title: XCUIElement = recorder.app.textFields[.editorTitle]
				try await recorder.require(title)
				title.tap()
				title.typeText(ExampleInput.noteTitle)
			}
		)
		try await navigate(recorder, from: .editorKeyboard, to: .notebooks, button: .saveNote, action: "Save the note")
	}

	internal func testSettingsJourney() async throws {
		let recorder: PyxisRecorder = try await launch(journey: .discoverPlus)
		try await recorder.capture(.home)
		try await navigate(recorder, from: .home, to: .settings, button: .openSettings, action: "Open settings")
		try await navigate(recorder, from: .settings, to: .subscription, button: .openSubscription, action: "Explore Notes Plus")
	}

	private func launch(journey: ExampleJourney) async throws -> PyxisRecorder {
		let profile: ExampleProfile = try .init(recordingEnvironment: ProcessInfo.processInfo.environment)
		let app: XCUIApplication = .init()
		let recorder: PyxisRecorder = try .init(
			testCase: self,
			app: app,
			configuration: .example(profile: profile, journey: journey)
		)
		addTeardownBlock { @MainActor in app.terminate() }
		try recorder.configureExampleDevice()
		try await recorder.launch(
			ready: { try await recorder.requireExampleState(.home) },
			readReport: { try recorder.readExampleReport() }
		)
		let report: PyxisBootstrapReport = try recorder.readExampleReport()
		for (key, value) in try profile.recording.requested {
			let result: PyxisVariantResult = try XCTUnwrap(report.variants[key])
			XCTAssertEqual(result.value, value, "Rendered variant: \(key)")
			XCTAssertTrue([.applied, .observed].contains(result.status), "Verified variant: \(key)")
		}
		return recorder
	}

	private func navigate(
		_ recorder: PyxisRecorder,
		from source: PyxisState,
		to destination: PyxisState,
		button identifier: ExampleElement,
		action: String
	) async throws {
		try await recorder.transition(
			from: source,
			to: destination,
			action: action,
			ready: { try await recorder.requireExampleState(destination) },
			perform: { try ExampleNavigation(app: recorder.app).tap(identifier) }
		)
	}
}
