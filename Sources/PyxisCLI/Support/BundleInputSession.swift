import Foundation
import PyxisProcessing

/// Owns extracted files for the lifetime of a CLI operation.
internal final class BundleInputSession {
	private let temporary: URL
	internal let inputs: [PyxisBundleInput]

	internal init(paths: [String]) throws {
		let temporary: URL = FileManager.default.temporaryDirectory
			.appendingPathComponent("pyxis-inputs-\(UUID().uuidString)")
		self.temporary = temporary
		do {
			self.inputs = try paths.enumerated().map { index, path in
				let url: URL = .init(fileURLWithPath: path)
				if ["pyx", "zip"].contains(url.pathExtension.lowercased()) {
					return try PyxisArchive().extract(from: url, to: temporary.appendingPathComponent(String(index)))
				}
				return try loadBundleInput(path)
			}
		} catch {
			// Keep the input error if cleanup fails.
			try? FileManager.default.removeItem(at: temporary)
			throw error
		}
	}

	deinit {
		// These files are disposable copies; sources are never removed.
		try? FileManager.default.removeItem(at: temporary)
	}
}
