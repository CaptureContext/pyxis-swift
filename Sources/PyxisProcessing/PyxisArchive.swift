import Foundation
import PyxisModel
import ZIPFoundation

/// Reads and writes self-contained regular artifacts, one ZIP entry at a time.
public struct PyxisArchive: Sendable {
	@inlinable
	public init() {}

	public func write(
		_ input: PyxisBundleInput,
		to output: URL
	) throws {
		try BundleValidator.validate(document: input.document, root: input.root)
		guard input.document.format == .map, output.isFileURL
		else { throw PyxisValidationError("Regular artifacts require a published map and a file destination") }
		let manager: FileManager = .default
		guard !manager.fileExists(atPath: output.path)
		else { throw PyxisValidationError("Archive already exists: \(output.path)") }
		let parent: URL = output.deletingLastPathComponent()
		try manager.createDirectory(at: parent, withIntermediateDirectories: true)
		let stage: URL = parent.appendingPathComponent(".pyxis-archive-\(UUID().uuidString).pyx")
		defer {
			// Preserve the original publication error if temporary-file cleanup also fails.
			try? manager.removeItem(at: stage)
		}
		try writeEntries(input, to: stage)
		try manager.moveItem(at: stage, to: output)
	}

	/// Extracts only validated metadata and referenced images into a new directory.
	public func extract(
		from source: URL,
		to output: URL
	) throws -> PyxisBundleInput {
		let manager: FileManager = .default
		guard source.isFileURL, output.isFileURL, !manager.fileExists(atPath: output.path)
		else { throw PyxisValidationError("Archive extraction requires a new file directory") }
		let archive: Archive = try .init(url: source, accessMode: .read)
		var entries: [String: Entry] = [:]
		var names: Set<String> = []
		for entry in archive {
			let path: String = entry.path.hasSuffix("/") ? String(entry.path.dropLast()) : entry.path
			try validateRelativeFilePath(path)
			guard names.insert(path).inserted, entry.type != .symlink
			else { throw PyxisValidationError("Duplicate or symbolic-link archive entries") }
			if entry.type == .file { entries[path] = entry }
		}
		let candidates: [String] = entries.keys.filter { $0 == "manifest.json" || $0.hasSuffix("/manifest.json") }
		let prefix: String
		if entries["manifest.json"] != nil {
			prefix = ""
		} else if candidates.count == 1 {
			prefix = String(candidates[0].dropLast("manifest.json".count))
		} else {
			throw PyxisValidationError("Archive must contain one recording manifest")
		}
		if source.pathExtension.lowercased() == "pyx", prefix != "" || entries["artifact.json"] == nil {
			throw PyxisValidationError("A .pyx requires artifact.json and manifest.json at its root")
		}
		if let descriptor = entries[prefix + "artifact.json"] {
			_ = try PyxisArtifact(data: read(descriptor, from: archive))
		}
		guard let manifest = entries[prefix + "manifest.json"]
		else { throw PyxisValidationError("Missing manifest.json") }
		let raw: Data = try read(manifest, from: archive)
		let document: PyxisMapDocument = try PyxisJSON.decode(raw)
		guard document.format == .map
		else { throw PyxisValidationError("An archive requires a published map") }
		let assets: Set<String> = .init(document.captures.map(\.asset.path))
		for path in assets where entries[prefix + path] == nil {
			throw PyxisValidationError("Missing asset: \(path)")
		}
		try manager.createDirectory(at: output, withIntermediateDirectories: true)
		do {
			try raw.write(to: output.appendingPathComponent("manifest.json"), options: .withoutOverwriting)
			try PyxisArtifact().encoded().write(to: output.appendingPathComponent("artifact.json"), options: .withoutOverwriting)
			for path in assets.sorted() {
				let target: URL = try BundleValidator.assetURL(path: path, root: output)
				try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
				let entry: Entry = entries[prefix + path]!
				let data: Data = try read(entry, from: archive)
				try data.write(to: target, options: .withoutOverwriting)
			}
			try BundleValidator.validate(document: document, root: output)
			return .init(document: document, root: output)
		} catch {
			// Extraction owns this new directory; never remove the source or an existing destination.
			try? manager.removeItem(at: output)
			throw error
		}
	}

	private func read(_ entry: Entry, from archive: Archive) throws -> Data {
		var bytes: Data = .init()
		let checksum: UInt32 = try archive.extract(entry) { chunk in
			guard UInt64(chunk.count) <= entry.uncompressedSize - UInt64(bytes.count)
			else { throw PyxisValidationError("Invalid archive entry size: \(entry.path)") }
			bytes.append(chunk)
		}
		guard checksum == entry.checksum, UInt64(bytes.count) == entry.uncompressedSize
		else { throw PyxisValidationError("Corrupt archive entry: \(entry.path)") }
		return bytes
	}

	private func writeEntries(_ input: PyxisBundleInput, to output: URL) throws {
		let archive: Archive = try .init(url: output, accessMode: .create)
		let metadata: [(String, Data)] = try [
			("artifact.json", PyxisArtifact().encoded()),
			("manifest.json", PyxisJSON.encode(input.document)),
		]
		for (path, bytes) in metadata {
			try archive.addEntry(
				with: path, type: .file, uncompressedSize: Int64(bytes.count),
				modificationDate: Date(timeIntervalSince1970: 315_532_800),
				compressionMethod: .deflate
			) { position, size in
				bytes.subdata(in: Int(position)..<(Int(position) + size))
			}
		}
		for path in Set(input.document.captures.map(\.asset.path)).sorted() {
			try archive.addEntry(with: path, relativeTo: input.root, compressionMethod: .deflate)
		}
	}
}
