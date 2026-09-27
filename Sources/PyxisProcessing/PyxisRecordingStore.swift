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
		let documents = try decodeSnapshot(bytes)
		let projectID = try decodeDescriptor().projectID
		guard documents.values.allSatisfy({ Data($0.project.id.utf8) == Data(projectID.utf8) })
		else { throw PyxisValidationError("Snapshot belongs to another project") }
		return .init(id: id, recordings: documents.keys.sorted().map { .init(document: documents[$0]!, root: root) })
	}

	private func decodeSnapshot(_ data: Data) throws -> [String: PyxisMapDocument] {
		// Explicitly migrated stores retain old snapshot bytes and IDs for historical references.
		if let value = try JSONSerialization.jsonObject(with: data) as? [String: Any], value["format"] as? String == "pyxis.map" {
			return try RecordingComposition().variations(PyxisJSON.decode(data))
		}
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let snapshot = try decoder.decode(StoreSnapshot.self, from: data)
		guard snapshot.format == "pyxis.store.snapshot", snapshot.version == 2, !snapshot.recordings.isEmpty else { throw PyxisValidationError("Unsupported store snapshot") }
		for (scope, document) in snapshot.recordings {
			let split = try RecordingComposition().variations(document)
			guard split.count == 1, split[scope] != nil else { throw PyxisValidationError("Invalid variation replacement slot") }
		}
		return snapshot.recordings
	}

	/// Replaces passed journey/test + requested-variant scopes. Other scopes survive a merge.
	@discardableResult
	public func update(
		_ input: PyxisBundleInput,
		context: String = "default",
		policy: PyxisStorePolicy = .merge
	) throws -> PyxisStoredRecording {
		try update([input], context: context, policy: policy, writer: .init())
	}

	/// Commits every selected input under one lock and advances the context only after all writes succeed.
	@discardableResult
	public func update(_ inputs: [PyxisBundleInput], context: String = "default", policy: PyxisStorePolicy = .merge) throws -> PyxisStoredRecording {
		try update(inputs, context: context, policy: policy, writer: .init())
	}

	@discardableResult
	internal func update(_ input: PyxisBundleInput, context: String = "default", policy: PyxisStorePolicy = .merge, writer: StoreFileWriter) throws -> PyxisStoredRecording {
		try update([input], context: context, policy: policy, writer: writer)
	}

	@discardableResult
	internal func update(
		_ inputs: [PyxisBundleInput],
		context: String = "default",
		policy: PyxisStorePolicy = .merge,
		writer: StoreFileWriter
	) throws -> PyxisStoredRecording {
		try validateContext(context)
		guard let input = inputs.first else { throw PyxisValidationError("Store update needs recordings") }
		var incoming: [String: PyxisMapDocument] = [:]
		for value in inputs {
			try BundleValidator.validate(document: value.document, root: value.root)
			guard Data(value.document.project.id.utf8) == Data(input.document.project.id.utf8) else { throw PyxisValidationError("Store inputs belong to different applications") }
			for (scope, document) in try RecordingComposition().variations(value.document) {
				if let previous = incoming[scope], previous != document { throw PyxisValidationError("More than one input replaces the same variation") }
				incoming[scope] = document
			}
		}
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
		var documents: [String: PyxisMapDocument] = [:]
		if policy == .merge, let previous {
			for value in previous.recordings { documents.merge(try RecordingComposition().variations(value.document)) { _, new in new } }
		}
		documents.merge(incoming) { _, new in new }
		var runs: [Data: PyxisRunMetadata] = [:]
		for document in documents.values {
			for run in [document.run] + document.recordingRuns {
				let key: Data = .init(run.id.utf8)
				if let previous = runs[key], previous != run {
					throw PyxisValidationError("Conflicting metadata for one immutable recording run")
				}
				runs[key] = run
			}
		}
		var prepared: Set<String> = []
		for input in inputs {
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
		}
		for document in documents.values { try BundleValidator.validate(document: document, root: root) }
		let bytes: Data = try encode(StoreSnapshot(recordings: documents))
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
		return .init(id: id, recordings: documents.keys.sorted().map { .init(document: documents[$0]!, root: root) })
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
		guard descriptor.format == "pyxis.store", descriptor.version == 2, !descriptor.projectID.isEmpty
		else { throw PyxisValidationError("Unsupported recording store. For version 1 use pyxis store migrate --output <new-directory>") }
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
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(value)
	}
}

private struct StoreSnapshot: Codable {
	internal var format: String
	internal var version: Int
	internal var recordings: [String: PyxisMapDocument]

	internal init(
		recordings: [String: PyxisMapDocument],
		format: String = "pyxis.store.snapshot",
		version: Int = 2
	) {
		self.format = format
		self.version = version
		self.recordings = recordings
	}
}
