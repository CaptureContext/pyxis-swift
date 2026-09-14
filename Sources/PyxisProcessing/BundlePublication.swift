import Darwin
import Foundation
import PyxisModel

/// Owns staging and atomic commit for both synchronous copying and async transforms.
internal final class BundlePublication {
	private let inputs: [PyxisBundleInput]
	private let manager: FileManager
	private let target: URL
	private let stage: URL
	private let hadTarget: Bool
	private var documents: [PyxisMapDocument]
	private var documentIndex: Int
	private var captureIndex: Int
	private var processed: [URL: (original: PyxisAsset, published: PyxisAsset)]
	private var written: Set<String>

	internal init(inputs: [PyxisBundleInput], to output: URL) throws {
		guard output.isFileURL
		else { throw PyxisValidationError("Output must be a file URL") }

		let manager = FileManager.default
		let originalTarget = output.standardizedFileURL

		let target = originalTarget
			.deletingLastPathComponent()
			.resolvingSymlinksInPath()
			.appendingPathComponent(originalTarget.lastPathComponent)

		if manager.fileExists(atPath: target.path) {
			let properties = try target.resourceValues(forKeys: [.isSymbolicLinkKey])
			if properties.isSymbolicLink == true { throw PyxisValidationError("Output may not be a symlink") }
		}

		for input in inputs {
			let source = input.root.standardizedFileURL.resolvingSymlinksInPath().path

			guard source != target.path,
				!source.hasPrefix(target.path + "/"),
				!target.path.hasPrefix(source + "/")
			else { throw PyxisValidationError("Output and input directories must not overlap") }
		}

		let hadTarget = manager.fileExists(atPath: target.path)
		if hadTarget { try Self.validateExistingTarget(target) }

		let parent = target.deletingLastPathComponent()
		try manager.createDirectory(
			at: parent,
			withIntermediateDirectories: true
		)

		let stage = parent.appendingPathComponent(".pyxis-stage-\(UUID().uuidString)")
		try manager.createDirectory(
			at: stage.appendingPathComponent("assets"),
			withIntermediateDirectories: true
		)

		self.inputs = inputs
		self.manager = manager
		self.target = target
		self.stage = stage
		self.hadTarget = hadTarget
		self.documents = inputs.map(\.document)
		self.documentIndex = 0
		self.captureIndex = 0
		self.processed = [:]
		self.written = []
	}

	internal func nextAsset() throws -> PublicationAsset? {
		while documentIndex < documents.count {
			if captureIndex == 0 { try PyxisValidation.validate(documents[documentIndex]) }
			guard captureIndex < documents[documentIndex].captures.count else {
				documentIndex += 1
				captureIndex = 0
				continue
			}
			let index: Int = captureIndex
			captureIndex += 1
			let original: PyxisAsset = documents[documentIndex].captures[index].asset
			let root: URL = inputs[documentIndex].root
			let source: URL = try BundleValidator.assetURL(path: original.path, root: root)
			if let previous = processed[source], previous.original == original {
				documents[documentIndex].captures[index].asset = previous.published
				continue
			}
			return .init(asset: original, root: root, source: source, documentIndex: documentIndex, captureIndex: index)
		}
		return nil
	}

	internal func write(_ content: PyxisAssetContent, for work: PublicationAsset) throws {
		var asset: PyxisAsset = content.asset
		let hash: String = StableID.sha256(content.bytes)
		let suffix: String = asset.mediaType == .png ? "png" : "jpg"
		asset.path = "assets/\(hash).\(suffix)"
		asset.sha256 = hash
		if written.insert(asset.path).inserted {
			try content.bytes.write(to: stage.appendingPathComponent(asset.path), options: .atomic)
		}
		processed[work.source] = (work.asset, asset)
		documents[work.documentIndex].captures[work.captureIndex].asset = asset
	}

	internal func commit() throws -> PyxisMapDocument {
		let merged: PyxisMapDocument = try MapMerger.merge(documents)
		try PyxisValidation.validate(merged)
		try PyxisArtifact().encoded().write(to: stage.appendingPathComponent("artifact.json"), options: .atomic)
		let manifest: Data = try PyxisJSON.encode(merged)

		try manifest.write(
			to: stage.appendingPathComponent("manifest.json"),
			options: .atomic
		)

		try BundleValidator.validate(
			document: merged,
			root: stage
		)

		if hadTarget {
			// Darwin's exchange leaves the last valid bundle in place even when rename fails.
			let result = stage.path.withCString { stagePath in
				target.path.withCString { targetPath in
					renameatx_np(AT_FDCWD, stagePath, AT_FDCWD, targetPath, UInt32(RENAME_SWAP))
				}
			}

			guard result == 0 else {
				throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
			}

			do {
				try manager.removeItem(at: stage)
			} catch {
				throw PyxisPublicationCleanupError(
					publishedAt: target,
					previousBundleAt: stage
				)
			}

		} else {
			try manager.moveItem(at: stage, to: target)
		}

		return merged
	}

	internal func fail(_ error: any Error) throws -> Never {
		if error is PyxisPublicationCleanupError { throw error }
		if manager.fileExists(atPath: stage.path) {
			do { try manager.removeItem(at: stage) }
			catch { throw PyxisValidationError("Publication failed; could not remove staging directory: \(stage.path)") }
		}
		throw error
	}

	private static func validateExistingTarget(_ target: URL) throws {
		let manager = FileManager.default
		let manifestURL = target.appendingPathComponent("manifest.json")
		let document = try PyxisJSON.decode(Data(contentsOf: manifestURL))

		guard document.format == .map
		else { throw PyxisValidationError("Existing output is not a published map") }

		try BundleValidator.validate(document: document, root: target)
		let allowed = Set(document.captures.map(\.asset.path)).union(["manifest.json", "artifact.json"])

		guard let enumerator = manager.enumerator(atPath: target.path)
		else { throw PyxisValidationError("Cannot inspect existing output") }

		while let relative = enumerator.nextObject() as? String {
			let file = target.appendingPathComponent(relative)
			let properties = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])

			guard properties.isSymbolicLink != true
			else { throw PyxisValidationError("Existing output contains symlink") }

			if properties.isDirectory == true {
				guard relative == "assets" || allowed.contains(where: { $0.hasPrefix(relative + "/") })
				else { throw PyxisValidationError("Existing output contains unrelated directory") }
			} else {
				guard allowed.contains(relative)
				else { throw PyxisValidationError("Existing output contains unrelated file: \(relative)") }
			}
		}
	}
}
