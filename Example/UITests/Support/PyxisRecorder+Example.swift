import ExampleTesting
import XCTest

extension PyxisRecorder {
	@MainActor
	internal func configureExampleDevice() throws {
		let environment: PyxisRecordingEnvironment = try .init(environment: ProcessInfo.processInfo.environment)
		app.launchEnvironment[PyxisRecordingEnvironment.Key.deviceModel.rawValue] = environment.deviceModel
		?? ExampleDevice.simulatorModel
		app.launchEnvironment[PyxisRecordingEnvironment.Key.deviceName.rawValue] = document.profiles[0].requested[PyxisVariantEntry.deviceKey]
	}

	@MainActor
	internal func readExampleReport() throws -> PyxisBootstrapReport {
		let element: XCUIElement = app.staticTexts[.report]
		try require(element)
		return try .init(encoded: XCTUnwrap(element.value as? String))
	}

	@MainActor
	internal func requireExampleState(_ state: PyxisState) async throws {
		let screen: ExampleScreen = try XCTUnwrap(ExampleScreen(rawValue: state.screenID))
		let element: XCUIElement = app.staticTexts[.ready(screen)]
		try await require(element)
		let requested: PyxisVariants = document.profiles[0].requested
		let traits: [String] = [
			PyxisVariantEntry.colorSchemeKey,
			PyxisVariantEntry.layoutDirectionKey,
			PyxisVariantEntry.accessibilityContentSizeKey,
		]
		let expected: String = try traits.map { try XCTUnwrap(requested[$0]) }.joined(separator: "|")
		XCTAssertEqual(element.value as? String, expected, "Rendered traits on \(state.screenID)")
		if state == .notebooksEmpty { try await require(app.descendants(matching: .any)[.notebooksEmpty]) }
		if state == .editorEmpty { XCTAssertFalse(app.buttons[.saveNote].isEnabled) }
		if state == .editorKeyboard {
			let keyboard: XCUIElement = app.keyboards.firstMatch
			let visible: Bool = try await keyboard.wait(for: \.isHittable, toEqual: true, timeout: .seconds(5))
			XCTAssertTrue(visible, "The keyboard must be visible in its recorded state")
			XCTAssertEqual(app.textFields[.editorTitle].value as? String, ExampleInput.noteTitle)
		}
	}
}
