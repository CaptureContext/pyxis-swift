import Darwin
import Foundation
import PyxisModel

internal final class StoreLock {
	private let descriptor: Int32

	internal init(at url: URL) throws {
		let descriptor: Int32 = open(url.path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
		guard descriptor >= 0
		else { throw PyxisValidationError("Cannot open recording-store lock") }
		guard flock(descriptor, LOCK_EX) == 0 else {
			close(descriptor)
			throw PyxisValidationError("Cannot lock recording store")
		}
		self.descriptor = descriptor
	}

	deinit {
		flock(descriptor, LOCK_UN)
		close(descriptor)
	}
}
