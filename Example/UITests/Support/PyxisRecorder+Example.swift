import ExampleTesting
import XCTest

extension PyxisRecorder {
	@MainActor
	internal func configureExampleDevice() throws {
		let orientation: String? = document.profiles[0].requested["orientation"]
		XCUIDevice.shared.orientation = orientation == "landscape" ? .landscapeLeft : .portrait
		let environment: PyxisRecordingEnvironment = try .init(environment: ProcessInfo.processInfo.environment)
		app.launchEnvironment[PyxisRecordingEnvironment.Key.deviceModel.rawValue] = environment.deviceModel
		?? ExampleDevice.simulatorModel
		app.launchEnvironment[PyxisRecordingEnvironment.Key.deviceName.rawValue] = document.profiles[0].requested[PyxisVariantEntry.deviceKey]
	}

	@MainActor
	internal func configureExampleOrientation() throws {
		let landscape: Bool = document.profiles[0].requested["orientation"] == "landscape"
		let preferred: UIDeviceOrientation = landscape ? .landscapeLeft : .portrait
		let alternate: UIDeviceOrientation = landscape ? .portrait : .landscapeLeft
		// XCTest can report stale application bounds on Duo's internal display; inspect its window.
		for orientation in [preferred, alternate, preferred] {
			XCUIDevice.shared.orientation = orientation
			let frame: CGRect = app.windows.firstMatch.frame
			if (frame.width > frame.height) == landscape { return }
		}
		throw PyxisRecorderError.readinessTimedOut("Requested display orientation")
	}

	@MainActor
	internal func readExampleReport() throws -> PyxisBootstrapReport {
		let element: XCUIElement = app.staticTexts[.report]
		try require(element)
		var report: PyxisBootstrapReport = try .init(encoded: XCTUnwrap(element.value as? String))
		if document.profiles[0].requested["orientation"] != nil {
			let frame: CGRect = app.windows.firstMatch.frame
			report.variants["orientation"] = .init(
				status: .observed,
				value: frame.width > frame.height ? "landscape" : "portrait"
			)
		}
		return report
	}

	@MainActor
	internal func requireExampleState(_ state: PyxisState) async throws {
		let screen: ExampleScreen = try XCTUnwrap(ExampleScreen(rawValue: state.screenID))
		let element: XCUIElement = app.staticTexts[.ready(screen)]
		try await require(element)
		let requested: PyxisVariants = document.profiles[0].requested
		if let orientation = requested["orientation"] {
			let frame: CGRect = app.windows.firstMatch.frame
			XCTAssertEqual(frame.width > frame.height ? "landscape" : "portrait", orientation, "Rendered orientation on \(state.screenID)")
		}
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
