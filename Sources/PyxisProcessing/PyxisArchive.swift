import Foundation
import PyxisModel
import ZIPFoundation

/// Portable archives retain physical child ZIPs so each extracted recording remains usable.
public struct PyxisArchive: Sendable {
	@inlinable
	public init() {}

	public func write(_ input: PyxisBundleInput, to output: URL) throws {
		try BundleValidator.validate(document: input.document, root: input.root)
		let scratch: URL = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-pack-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: scratch) }
		let tests = Dictionary(grouping: input.document.observations) {
			$0.recordingKey.map { StableID.digest(parts: ["recording_scope", $0]) }
			?? StableID.digest(parts: ["store_scope", $0.journeyID, $0.testName])
		}
		var children: [URL] = []
		for (testIndex, key) in tests.keys.sorted().enumerated() {
			let profiles = try Dictionary(grouping: tests[key]!) { observation in
				try StableID.sha256(encode(input.document.profiles.first { $0.id == observation.profileID }!.requested))
			}
			var variations: [URL] = []
			for (index, observations) in profiles.values.sorted(by: { $0[0].id < $1[0].id }).enumerated() {
				let file = scratch.appendingPathComponent("variation-\(testIndex)-\(index).pyx")
				try writeLeaf(.init(document: Self.subset(input.document, observations: observations), root: input.root), to: file)
				variations.append(file)
			}
			let file = scratch.appendingPathComponent("test-\(testIndex).pyx")
			try compose(variations, to: file)
			children.append(file)
		}
		if children.isEmpty { try writeLeaf(input, to: output) }
		else { try compose(children, to: output) }
	}

	public func write(_ inputs: [PyxisBundleInput], to output: URL) throws {
		guard !inputs.isEmpty else { throw PyxisValidationError("An archive needs recordings") }
		if inputs.count == 1 { try write(inputs[0], to: output); return }
		let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-compose-inputs-\(UUID().uuidString)")
		try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: scratch) }
		var sources: [URL] = []
		for (index, input) in inputs.enumerated() {
			let file = scratch.appendingPathComponent("\(index).pyx")
			try write(input, to: file)
			sources.append(file)
		}
		try compose(sources, to: output)
	}

	/// Compose existing archives without flattening them or changing their identities.
	public func compose(_ sources: [URL], to output: URL) throws {
		let references = try references(for: sources)
		guard !references.isEmpty else { throw PyxisValidationError("A composition needs recordings") }
		let id = StableID.digest(parts: references.flatMap { [$0.id, $0.sha256] })
		let descriptor: PyxisArtifact = .init(type: .composition, id: id, recordings: references)
		try create(to: output) { archive in
			try add("artifact.json", bytes: descriptor.encoded(), to: archive)
			for (source, reference) in zip(sources, references) {
				try add(reference.path, bytes: Data(contentsOf: source, options: .mappedIfSafe), to: archive)
			}
		}
	}

	public func writeDocument(
		_ document: PyxisVisualizationDocument,
		sources: [URL],
		to output: URL
	) throws {
		try document.validate()
		guard try references(for: sources) == document.recordings
		else { throw PyxisValidationError("Document sources do not match its embedded references") }
		try create(to: output) { archive in
			try add("document.json", bytes: encode(document), to: archive)
			for (source, reference) in zip(sources, document.recordings) {
				try add(reference.path, bytes: Data(contentsOf: source, options: .mappedIfSafe), to: archive)
			}
		}
	}

	public func references(for sources: [URL]) throws -> [PyxisArtifactReference] {
		let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-validate-sources-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: scratch) }
		var identities: [Data: String] = [:]
		return try sources.enumerated().map { index, source in
			let directory = scratch.appendingPathComponent(String(index))
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			_ = try extractTree(from: source, to: directory, allowLegacy: false, identities: &identities)
			let archive: Archive = try .init(url: source, accessMode: .read)
			let entries = try entries(in: archive)
			guard let entry = entries["artifact.json"]
			else { throw PyxisValidationError("Embedded recordings need artifact.json") }
			let descriptor = try PyxisArtifact(data: read(entry, from: archive))
			let bytes = try Data(contentsOf: source, options: .mappedIfSafe)
			return .init(id: descriptor.id!, path: "assets/recording-\(index).pyx", sha256: StableID.sha256(bytes))
		}
	}

	/// Migration is explicit. It never changes the original file.
	public func migrate(from source: URL, to output: URL) throws {
		let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-migrate-\(UUID().uuidString)")
		defer { try? FileManager.default.removeItem(at: scratch) }
		let inputs = try extractRecordings(from: source, to: scratch, allowLegacy: true)
		guard inputs.count == 1 else { throw PyxisValidationError("Migration expects one legacy regular recording") }
		try write(inputs[0], to: output)
	}

	public func extract(from source: URL, to output: URL) throws -> PyxisBundleInput {
		let inputs = try extractRecordings(from: source, to: output)
		if inputs.count == 1 { return inputs[0] }
		let merged = output.appendingPathComponent("merged")
		return try .init(document: BundlePublisher.publish(inputs: inputs, to: merged), root: merged)
	}

	/// Returns original leaf records; callers can compose different runs without conflating their metadata.
	public func extractRecordings(
		from source: URL,
		to output: URL,
		allowLegacy: Bool = false
	) throws -> [PyxisBundleInput] {
		let manager = FileManager.default
		guard source.isFileURL, output.isFileURL, !manager.fileExists(atPath: output.path)
		else { throw PyxisValidationError("Archive extraction requires a new file directory") }
		try manager.createDirectory(at: output, withIntermediateDirectories: true)
		do {
			var identities: [Data: String] = [:]
			return try extractTree(from: source, to: output, allowLegacy: allowLegacy, identities: &identities)
		} catch {
			try? manager.removeItem(at: output)
			throw error
		}
	}

	private func extractTree(
		from source: URL,
		to output: URL,
		allowLegacy: Bool,
		identities: inout [Data: String]
	) throws -> [PyxisBundleInput] {
		let archive: Archive = try .init(url: source, accessMode: .read)
		let entries = try entries(in: archive)
		let references: [PyxisArtifactReference]
		if let documentEntry = entries["document.json"] {
			let raw = try read(documentEntry, from: archive)
			let document = try PyxisVisualizationDocument(data: raw)
			try document.validate()
			references = document.recordings
			try raw.write(to: output.appendingPathComponent("document.json"))
		} else {
			guard let descriptorEntry = entries["artifact.json"]
			else { throw PyxisValidationError("A recording requires artifact.json at its root") }
			let descriptor = try PyxisArtifact(data: read(descriptorEntry, from: archive), allowLegacy: allowLegacy)
			if let id = descriptor.id {
				let checksum = try StableID.sha256(Data(contentsOf: source, options: .mappedIfSafe))
				if let previous = identities[Data(id.utf8)], previous != checksum {
					throw PyxisValidationError("Conflicting archive contents for identity: \(id)")
				}
				identities[Data(id.utf8)] = checksum
			}
			if descriptor.type == .regular {
				guard let manifest = entries["manifest.json"]
				else { throw PyxisValidationError("Missing manifest.json") }
				let raw = try read(manifest, from: archive)
				let document = try PyxisJSON.decode(raw)
				guard document.format == .map else { throw PyxisValidationError("An archive requires a published map") }
				try raw.write(to: output.appendingPathComponent("manifest.json"))
				let converted = descriptor.version == 1 ? PyxisArtifact(id: StableID.sha256(raw)) : descriptor
				try converted.encoded().write(to: output.appendingPathComponent("artifact.json"))
				for path in Set(document.captures.map(\.asset.path)).sorted() {
					guard let entry = entries[path] else { throw PyxisValidationError("Missing asset: \(path)") }
					let target = try BundleValidator.assetURL(path: path, root: output)
					try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
					try read(entry, from: archive).write(to: target)
				}
				try BundleValidator.validate(document: document, root: output)
				return [.init(document: document, root: output)]
			}
			references = descriptor.recordings
			try descriptor.encoded().write(to: output.appendingPathComponent("artifact.json"))
		}
		var result: [PyxisBundleInput] = []
		for (index, reference) in references.enumerated() {
			guard let entry = entries[reference.path] else { throw PyxisValidationError("Missing recording: \(reference.path)") }
			let bytes = try read(entry, from: archive)
			guard StableID.sha256(bytes) == reference.sha256 else { throw PyxisValidationError("Recording checksum mismatch") }
			let child = output.appendingPathComponent("recording-\(index).pyx")
			try bytes.write(to: child)
			let childArchive: Archive = try .init(url: child, accessMode: .read)
			guard let descriptorEntry = try self.entries(in: childArchive)["artifact.json"],
				try PyxisArtifact(data: read(descriptorEntry, from: childArchive)).id.map({ Data($0.utf8) }) == Data(reference.id.utf8)
			else { throw PyxisValidationError("Embedded recording identity mismatch") }
			let folder = output.appendingPathComponent("recording-\(index)")
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			result += try extractTree(from: child, to: folder, allowLegacy: false, identities: &identities)
		}
		return result
	}

	private func writeLeaf(_ input: PyxisBundleInput, to output: URL) throws {
		try BundleValidator.validate(document: input.document, root: input.root)
		let manifest = try PyxisJSON.encode(input.document)
		let descriptor: PyxisArtifact = .init(id: StableID.sha256(manifest))
		try create(to: output) { archive in
			try add("artifact.json", bytes: descriptor.encoded(), to: archive)
			try add("manifest.json", bytes: manifest, to: archive)
			for path in Set(input.document.captures.map(\.asset.path)).sorted() {
				try add(path, bytes: Data(contentsOf: input.root.appendingPathComponent(path), options: .mappedIfSafe), to: archive)
			}
		}
	}

	internal static func subset(_ source: PyxisMapDocument, observations: [PyxisObservation]) -> PyxisMapDocument {
		var result = source
		let observationIDs = Set(observations.map(\.id))
		result.observations = observations
		result.captures = source.captures.filter { observationIDs.contains($0.observationID) }
		result.transitions = source.transitions.filter { observationIDs.contains($0.observationID) }
		let states = Set(result.captures.map(\.stateID) + result.transitions.flatMap { [$0.fromStateID, $0.toStateID] })
		result.states = source.states.filter { states.contains($0.id) }
		let domains = Set(result.states.map(\.domainID))
		result.domains = source.domains.filter { domains.contains($0.id) }
		let profiles = Set(observations.map(\.profileID))
		result.profiles = source.profiles.filter { profiles.contains($0.id) }
		return result
	}

	private func entries(in archive: Archive) throws -> [String: Entry] {
		var result: [String: Entry] = [:]
		var names: Set<String> = []
		for entry in archive {
			let path = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
			try validateRelativeFilePath(path)
			guard names.insert(path).inserted, entry.type != .symlink
			else { throw PyxisValidationError("Duplicate or symbolic-link archive entry") }
			if entry.type == .file { result[path] = entry }
		}
		return result
	}

	private func read(_ entry: Entry, from archive: Archive) throws -> Data {
		var bytes = Data()
		let checksum = try archive.extract(entry) { chunk in
			guard UInt64(chunk.count) <= entry.uncompressedSize - UInt64(bytes.count)
			else { throw PyxisValidationError("Invalid ZIP entry size") }
			bytes.append(chunk)
		}
		guard checksum == entry.checksum, UInt64(bytes.count) == entry.uncompressedSize
		else { throw PyxisValidationError("Corrupt ZIP entry") }
		return bytes
	}

	private func add(_ path: String, bytes: Data, to archive: Archive) throws {
		try archive.addEntry(
			with: path, type: .file, uncompressedSize: Int64(bytes.count),
			modificationDate: Date(timeIntervalSince1970: 315_532_800), compressionMethod: .deflate
		) { position, size in bytes.subdata(in: Int(position)..<(Int(position) + size)) }
	}

	private func create(to output: URL, write: (Archive) throws -> Void) throws {
		let manager = FileManager.default
		guard output.isFileURL, !manager.fileExists(atPath: output.path)
		else { throw PyxisValidationError("Archive destination must be a new file") }
		try manager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
		let stage = output.deletingLastPathComponent().appendingPathComponent(".pyxis-\(UUID().uuidString).zip")
		defer { try? manager.removeItem(at: stage) }
		try write(Archive(url: stage, accessMode: .create))
		try manager.moveItem(at: stage, to: output)
	}

	private func encode<Value: Encodable>(_ value: Value) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(value)
	}
}
