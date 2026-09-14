import Foundation

/// SwiftPM forwards plugin output through a pipe, which otherwise buffers long-running progress.
internal func printProgress(_ message: String) {
	print(message)
	fflush(nil)
}
