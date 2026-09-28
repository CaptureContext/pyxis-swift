import Foundation
import ImageIO
import PyxisModel
import PyxisProcessing

internal struct FFmpegImageOptimizer {
	internal let executable: URL
	internal let maximumWidth: Int
	internal let scratch: URL

	internal init(
		executable: URL,
		maximumWidth: Int,
		scratch: URL
	) {
		self.executable = executable
		self.maximumWidth = maximumWidth
		self.scratch = scratch
	}

	internal func optimize(
		asset: PyxisAsset,
		bytes: Data
	) async throws -> PyxisAssetContent {
		let source = CGImageSourceCreateWithData(bytes as CFData, nil)
		let properties = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
		let orientation: Int = properties?[kCGImagePropertyOrientation] as? Int ?? 1
		// ffmpeg applies EXIF orientation before scaling, including quarter-turn rotations.
		let swapsDimensions: Bool = (5...8).contains(orientation)
		let displayWidth: Int = swapsDimensions ? asset.height : asset.width
		let displayHeight: Int = swapsDimensions ? asset.width : asset.height
		guard displayWidth > maximumWidth
		else { return .init(asset: asset, bytes: bytes) }

		let height: Int = max(1, Int((Double(displayHeight) * Double(maximumWidth) / Double(displayWidth)).rounded()))
		let suffix: String = asset.mediaType == .png ? "png" : "jpg"
		let input: URL = scratch.appendingPathComponent("input.\(suffix)")
		let output: URL = scratch.appendingPathComponent("assets/output.\(suffix)")
		let log: URL = scratch.appendingPathComponent("ffmpeg.log")
		let manager: FileManager = .default
		try manager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
		if manager.fileExists(atPath: log.path) { try manager.removeItem(at: log) }
		try bytes.write(to: input, options: .atomic)

		let status: Int32 = try await runProcess(
			executable.path,
			[
				"-nostdin", "-v", "error", "-y", "-i", input.path,
				"-vf", "scale=\(maximumWidth):\(height):flags=lanczos",
				"-frames:v", "1", "-threads", "1",
				"-c:v", asset.mediaType == .png ? "png" : "mjpeg",
				output.path,
			],
			log: log
		)
		guard status == 0 else {
			let details: String = try String(contentsOf: log, encoding: .utf8)
			throw CLIError.operation("ffmpeg failed for \(asset.path): \(details)")
		}

		var resized: PyxisAsset = asset
		resized.path = "assets/" + output.lastPathComponent
		resized.sha256 = nil
		resized.width = maximumWidth
		resized.height = height
		return try .init(
			asset: resized,
			bytes: BundleValidator.assetData(resized, root: scratch)
		)
	}
}

internal func ffmpegExecutable(
	path: String?,
	environment: [String: String] = ProcessInfo.processInfo.environment
) throws -> URL {
	let command: String = path ?? "ffmpeg"
	let candidates: [URL] = command.contains("/")
	? [URL(fileURLWithPath: command)]
	: (environment["PATH"] ?? "").split(separator: ":").map {
		URL(fileURLWithPath: String($0)).appendingPathComponent(command)
	}
	guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
		throw CLIError.operation("Image resizing requires ffmpeg. Install it on PATH or pass --ffmpeg /path/to/ffmpeg.")
	}
	return executable
}
