import ExampleTesting
import XCTest

@MainActor
internal struct ExampleNavigation {
	internal let app: XCUIApplication

	internal init(app: XCUIApplication) {
		self.app = app
	}

	internal func tap(_ identifier: ExampleElement) throws {
		let button: XCUIElement = app.buttons[identifier]
		// SwiftUI lists may not expose offscreen rows until they have been scrolled into view.
		for _ in 0..<6 {
			if button.exists, button.isHittable {
				button.tap()
				return
			}
			app.swipeUp()
		}
		throw PyxisRecorderError.readinessTimedOut(identifier.identifier)
	}
}
