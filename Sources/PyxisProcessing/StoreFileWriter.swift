import Darwin
import Foundation
import PyxisModel

/// Stages writes on the store's filesystem; only complete, synchronized files become visible.
internal struct StoreFileWriter: Sendable {
	private let prepare: @Sendable (Data, URL, URL) throws -> Void

	internal init(
		prepare: @escaping @Sendable (Data, URL, URL) throws -> Void = { data, temporary, _ in
			try data.write(to: temporary, options: .withoutOverwriting)
			let handle: FileHandle = try .init(forWritingTo: temporary)
			do {
				try handle.synchronize()
				try handle.close()
			} catch {
				// Preserve the write/flush error if closing also fails.
				try? handle.close()
				throw error
			}
		}
	) {
		self.prepare = prepare
	}

	internal func write(
		_ data: Data,
		to destination: URL,
		staging: URL
	) throws {
		let temporary: URL = staging.appendingPathComponent("\(UUID().uuidString).tmp")
		defer {
			// A crash can leave this file behind; recovery retries cleanup under the writer lock.
			try? FileManager.default.removeItem(at: temporary)
		}
		try prepare(data, temporary, destination)
		guard rename(temporary.path, destination.path) == 0
		else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
	}

	/// Called under the writer lock after verifying this directory belongs to the expected project.
	internal func recover(in staging: URL) throws {
		let manager: FileManager = .default
		try manager.createDirectory(at: staging, withIntermediateDirectories: true)
		let pending: [URL] = try manager.contentsOfDirectory(
			at: staging,
			includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
		)
		// Validate every entry before removing anything. Never follow links or prune retained data.
		for url in pending {
			let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
			guard
				url.pathExtension == "tmp",
				UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil,
				values.isRegularFile == true,
				values.isSymbolicLink != true
			else { throw PyxisValidationError("Unrecognized file in recording-store staging") }
		}
		for url in pending { try manager.removeItem(at: url) }
	}
}
