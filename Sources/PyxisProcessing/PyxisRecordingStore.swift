import Foundation
import PyxisModel

/// A consumer-owned directory of immutable assets and snapshots, with explicitly named contexts.
public struct PyxisRecordingStore: Sendable {
	public let root: URL

	@inlinable
	public init(root: URL) {
		self.root = root
	}

	public func snapshot(context: String = "default") throws -> PyxisStoredRecording? {
		try validateContext(context)
		guard FileManager.default.fileExists(atPath: root.path) else { return nil }
		try validateStore()
		let head: URL = try file("heads/\(context).json")
		guard FileManager.default.fileExists(atPath: head.path) else { return nil }
		let value: StoreHead = try JSONDecoder().decode(StoreHead.self, from: metadata(at: head))
		return try snapshot(id: value.snapshotID)
	}

	public func snapshot(id: String) throws -> PyxisStoredRecording {
		guard id.count == 64, id.allSatisfy({ "0123456789abcdef".contains($0) })
		else { throw PyxisValidationError("Invalid snapshot ID") }
		try validateStore()
		let bytes: Data = try metadata(at: file("snapshots/\(id).json"))
		guard StableID.sha256(bytes) == id
		else { throw PyxisValidationError("Snapshot checksum mismatch") }
		let document: PyxisMapDocument = try PyxisJSON.decode(bytes)
		guard try Data(document.project.id.utf8) == Data(decodeDescriptor().projectID.utf8)
		else { throw PyxisValidationError("Snapshot belongs to another project") }
		return .init(id: id, bundle: .init(document: document, root: root))
	}

	/// Replaces passed journey/test + requested-variant scopes. Other scopes survive a merge.
	@discardableResult
	public func update(
		_ input: PyxisBundleInput,
		context: String = "default",
		policy: PyxisStorePolicy = .merge
	) throws -> PyxisStoredRecording {
		try update(input, context: context, policy: policy, writer: .init())
	}

	@discardableResult
	internal func update(
		_ input: PyxisBundleInput,
		context: String = "default",
		policy: PyxisStorePolicy = .merge,
		writer: StoreFileWriter
	) throws -> PyxisStoredRecording {
		try validateContext(context)
		try BundleValidator.validate(document: input.document, root: input.root)
		guard input.document.format == .map, !input.document.observations.isEmpty,
			input.document.observations.allSatisfy({ $0.status == .passed })
		else { throw PyxisValidationError("Store updates require nonempty, passed recordings") }
		try prepareLock()
		let lock: StoreLock = try .init(at: file(".runtime/write.lock"))
		defer { withExtendedLifetime(lock) {} }
		let needsDescriptor: Bool = try validateDestination(projectID: input.document.project.id)
		let staging: URL = try file(".runtime/staging")
		try writer.recover(in: staging)
		if needsDescriptor {
			try writer.write(
				encode(StoreDescriptor(projectID: input.document.project.id)),
				to: file("store.json"), staging: staging
			)
		}
		for path in ["assets", "heads", "snapshots"] {
			try FileManager.default.createDirectory(at: file(path), withIntermediateDirectories: true)
		}
		let previous: PyxisStoredRecording? = try snapshot(context: context)
		let document: PyxisMapDocument = try RecordingComposition().compose(
			previous: previous?.bundle.document, incoming: input.document, policy: policy
		)
		var prepared: Set<String> = []
		for capture in input.document.captures where prepared.insert(capture.asset.path).inserted {
			let asset: PyxisAsset = capture.asset
			guard let hash = asset.sha256,
				asset.path == "assets/\(hash).\(asset.mediaType == .png ? "png" : "jpg")"
			else { throw PyxisValidationError("Publish the input before updating a store; assets must use SHA-256 filenames") }
			let target: URL = try file(asset.path)
			if FileManager.default.fileExists(atPath: target.path) {
				_ = try BundleValidator.assetData(asset, root: root)
			} else {
				try writer.write(BundleValidator.assetData(asset, root: input.root), to: target, staging: staging)
			}
		}
		try BundleValidator.validate(document: document, root: root)
		let bytes: Data = try PyxisJSON.encode(document)
		let id: String = StableID.sha256(bytes)
		let snapshotFile: URL = try file("snapshots/\(id).json")
		if FileManager.default.fileExists(atPath: snapshotFile.path) {
			guard try metadata(at: snapshotFile) == bytes
			else { throw PyxisValidationError("Existing snapshot is corrupt") }
		} else {
			try writer.write(bytes, to: snapshotFile, staging: staging)
		}
		try writer.write(
			encode(StoreHead(snapshotID: id)),
			to: file("heads/\(context).json"), staging: staging
		)
		return .init(id: id, bundle: .init(document: document, root: root))
	}

	private func prepareLock() throws {
		guard root.isFileURL
		else { throw PyxisValidationError("A recording store requires a filesystem directory") }
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: file(".runtime"), withIntermediateDirectories: true)
	}

	/// Inspect initialization state only while holding the same lock as established-store updates.
	private func validateDestination(projectID: String) throws -> Bool {
		let url: URL = try file("store.json")
		guard FileManager.default.fileExists(atPath: url.path) else {
			let names: [String] = try FileManager.default.contentsOfDirectory(atPath: root.path)
			guard names.allSatisfy({ $0 == ".runtime" })
			else { throw PyxisValidationError("Store destination contains unrelated files") }
			return true
		}
		try validateStore()
		let descriptor: StoreDescriptor = try decodeDescriptor()
		guard Data(descriptor.projectID.utf8) == Data(projectID.utf8)
		else { throw PyxisValidationError("Store belongs to another project") }
		return false
	}

	private func validateStore() throws {
		let descriptor: StoreDescriptor = try decodeDescriptor()
		guard descriptor.format == "pyxis.store", descriptor.version == 1, !descriptor.projectID.isEmpty
		else { throw PyxisValidationError("Unsupported recording store") }
	}

	private func decodeDescriptor() throws -> StoreDescriptor {
		try JSONDecoder().decode(StoreDescriptor.self, from: metadata(at: file("store.json")))
	}

	private func file(_ relative: String) throws -> URL {
		guard root.isFileURL else { throw PyxisValidationError("Store root must be a file URL") }
		try validateRelativeFilePath(relative)
		var candidate: URL = root.standardizedFileURL.resolvingSymlinksInPath()
		for component in relative.split(separator: "/") {
			candidate.appendPathComponent(String(component))
			if let values = try? candidate.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
				throw PyxisValidationError("Symbolic links inside recording stores are unsupported")
			}
		}
		return candidate
	}

	private func metadata(at url: URL) throws -> Data {
		let values = try url.resourceValues(forKeys: [.isRegularFileKey])
		guard values.isRegularFile == true
		else { throw PyxisValidationError("Invalid recording-store metadata file") }
		return try Data(contentsOf: url)
	}

	private func validateContext(_ context: String) throws {
		try validateRelativeFilePath(context)
		guard !context.contains("/"), context.utf8.count <= 128
		else { throw PyxisValidationError("A store context must be one ASCII-safe path segment, up to 128 bytes") }
	}

	private func encode<Value: Encodable>(_ value: Value) throws -> Data {
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(value)
	}
}
