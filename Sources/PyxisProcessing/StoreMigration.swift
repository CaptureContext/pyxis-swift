import Foundation
import PyxisModel

extension PyxisRecordingStore {
	/// Converts a legacy store into a separate validated store. The source and all revision IDs survive.
	public static func migrate(from source: URL, to output: URL) throws {
		let manager = FileManager.default
		let source = source.standardizedFileURL.resolvingSymlinksInPath()
		let output = output.standardizedFileURL.resolvingSymlinksInPath()
		guard source.isFileURL, output.isFileURL, !manager.fileExists(atPath: output.path),
			!output.path.hasPrefix(source.path + "/"), !source.path.hasPrefix(output.path + "/")
		else { throw PyxisValidationError("Store migration requires a separate new destination") }
		for path in ["store.json", ".runtime", ".runtime/write.lock"] {
			let values = try source.appendingPathComponent(path).resourceValues(forKeys: [.isSymbolicLinkKey])
			guard values.isSymbolicLink != true else { throw PyxisValidationError("Store migration rejects symbolic links") }
		}
		let descriptor = try JSONDecoder().decode(StoreDescriptor.self, from: Data(contentsOf: source.appendingPathComponent("store.json")))
		guard descriptor.format == "pyxis.store", descriptor.version == 1, !descriptor.projectID.isEmpty
		else { throw PyxisValidationError("Migration requires a version 1 recording store") }
		let lock = try StoreLock(at: source.appendingPathComponent(".runtime/write.lock"))
		defer { withExtendedLifetime(lock) {} }
		let stage = output.deletingLastPathComponent().appendingPathComponent(".pyxis-migrate-store-\(UUID().uuidString)")
		try manager.createDirectory(at: stage, withIntermediateDirectories: true)
		defer { try? manager.removeItem(at: stage) }
		for category in ["assets", "heads", "snapshots"] {
			let directory = source.appendingPathComponent(category)
			guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]).isSymbolicLink != true else { throw PyxisValidationError("Store migration rejects symbolic links") }
			try manager.createDirectory(at: stage.appendingPathComponent(category), withIntermediateDirectories: true)
			guard let enumerator = manager.enumerator(atPath: directory.path)
			else { throw PyxisValidationError("Missing store directory: \(category)") }
			for case let entry as String in enumerator {
				let file: URL = directory.appendingPathComponent(entry)
				let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
				guard values.isSymbolicLink != true else { throw PyxisValidationError("Store migration rejects symbolic links") }
				let relative: String = "\(category)/\(entry)"
				try validateRelativeFilePath(relative)
				let target = stage.appendingPathComponent(relative)
				if values.isDirectory == true { try manager.createDirectory(at: target, withIntermediateDirectories: true) }
				else {
					guard values.isRegularFile == true else { throw PyxisValidationError("Unsupported store entry") }
					try manager.copyItem(at: file, to: target)
				}
			}
		}
		let encoded = try JSONEncoder().encode(StoreDescriptor(projectID: descriptor.projectID))
		try encoded.write(to: stage.appendingPathComponent("store.json"))
		let migrated = PyxisRecordingStore(root: stage)
		for file in try manager.contentsOfDirectory(at: stage.appendingPathComponent("snapshots"), includingPropertiesForKeys: nil) {
			let recording = try migrated.snapshot(id: file.deletingPathExtension().lastPathComponent)
			for input in recording.recordings { try BundleValidator.validate(document: input.document, root: input.root) }
		}
		for file in try manager.contentsOfDirectory(at: stage.appendingPathComponent("heads"), includingPropertiesForKeys: nil) {
			_ = try migrated.snapshot(context: file.deletingPathExtension().lastPathComponent)
		}
		try manager.moveItem(at: stage, to: output)
	}
}
