/// The content included in recorded screenshots and failure diagnostics.
public enum PyxisScreenshotSource: Sendable {
	/// Capture the application's own content.
	case application
	/// Capture the main display, including system UI such as the software keyboard.
	case screen
}
