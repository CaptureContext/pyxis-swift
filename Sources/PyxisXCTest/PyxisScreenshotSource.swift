/// The content included in recorded screenshots and failure diagnostics.
public enum PyxisScreenshotSource: Sendable, Hashable {
	/// Capture the application's own content.
	case application
	/// Capture the main display, including system UI such as the software keyboard.
	case screen
	/// Capture a display by its zero-based index in `XCUIScreen.screens`.
	case display(index: Int)
}
