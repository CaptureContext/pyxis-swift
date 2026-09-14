import Foundation
import ImageIO
import PyxisModel

public enum BundleValidator {
	public static func validate(document: PyxisMapDocument, root: URL) throws {
		try PyxisValidation.validate(document)
		let descriptor: URL = try relativeFileURL(path: "artifact.json", root: root)
		if FileManager.default.fileExists(atPath: descriptor.path) {
			let values = try descriptor.resourceValues(forKeys: [.isRegularFileKey])
			guard values.isRegularFile == true
			else { throw PyxisValidationError("Invalid artifact descriptor file") }
			_ = try PyxisArtifact(data: Data(contentsOf: descriptor))
		}
		var seen: Set<String> = []
		for capture in document.captures where seen.insert(capture.asset.path).inserted {
			_ = try autoreleasepool { try assetData(capture.asset, root: root) }
		}
	}

	public static func assetData(_ asset: PyxisAsset, root: URL) throws -> Data {
		try PyxisValidation.validateAsset(asset, requireHash: false)
		let url = try assetURL(path: asset.path, root: root)
		let values = try url.resourceValues(forKeys: [.isRegularFileKey])

		guard values.isRegularFile == true
		else { throw PyxisValidationError("Asset is not a regular file") }

		let bytes = try Data(contentsOf: url)

		if let expected = asset.sha256, StableID.sha256(bytes) != expected {
			throw PyxisValidationError("Asset checksum mismatch: \(asset.path)")
		}

		let pngSignature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
		let signatureMatches = asset.mediaType == .png
		? bytes.starts(with: pngSignature)
		: bytes.starts(with: [255, 216, 255])

		guard signatureMatches
		else { throw PyxisValidationError("Asset media type mismatch") }

		guard
			let source = CGImageSourceCreateWithData(bytes as CFData, nil),
			CGImageSourceGetCount(source) == 1,
			let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
			let actualWidth = properties[kCGImagePropertyPixelWidth] as? Int,
			let actualHeight = properties[kCGImagePropertyPixelHeight] as? Int,
			actualWidth == asset.width, actualHeight == asset.height,
			let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
			image.width == asset.width,
			image.height == asset.height,
			CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
		else { throw PyxisValidationError("Invalid image or mismatched dimensions: \(asset.path)") }

		return bytes
	}

	public static func assetURL(path: String, root: URL) throws -> URL {
		guard root.isFileURL
		else { throw PyxisValidationError("Bundle root must be a file URL") }

		try PyxisValidation.validatePath(path)

		let resolvedRoot = root
			.standardizedFileURL
			.resolvingSymlinksInPath()

		let candidate = resolvedRoot
			.appendingPathComponent(path)
			.standardizedFileURL.resolvingSymlinksInPath()

		guard candidate.path.hasPrefix(resolvedRoot.path + "/")
		else { throw PyxisValidationError("Asset symlink escapes bundle root") }

		return candidate
	}
}
