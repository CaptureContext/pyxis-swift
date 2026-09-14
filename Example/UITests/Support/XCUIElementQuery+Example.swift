import ExampleTesting
import XCTest

internal extension XCUIElementQuery {
	subscript(_ element: ExampleElement) -> XCUIElement {
		self[element.identifier]
	}
}
