import ArgumentParser
import Foundation
import PyxisModel
import PyxisProcessing

internal struct PublicationOptions: ParsableArguments {
	@Option(
		name: .long,
		help: "Maximum image width in pixels. Preserves proportions and never upscales. Requires ffmpeg."
	)
	internal var imageWidth: Int?

	@Option(
		name: .long,
		help: "Convert images to JPEG at quality 0...1, using Apple's ImageIO encoder. Omit to preserve the original format."
	)
	internal var jpegQuality: Double?

	@Option(
		name: .long,
		help: "ffmpeg executable path. Defaults to ffmpeg on PATH."
	)
	internal var ffmpeg: String?

	@Option(
		name: .long,
		help: "Also write one regular .pyx archive at this new path, outside the output directory. Existing archives are never overwritten."
	)
	internal var archive: String?

	internal init() {}

	internal init(
		imageWidth: Int?,
		jpegQuality: Double? = nil,
		ffmpeg: String? = nil,
		archive: String? = nil
	) {
		self.imageWidth = imageWidth
		self.jpegQuality = jpegQuality
		self.ffmpeg = ffmpeg
		self.archive = archive
	}

	internal func validate() throws {
		if let imageWidth {
			guard imageWidth > 0
			else { throw ArgumentParser.ValidationError("--image-width must be positive.") }
		}
		if let jpegQuality {
			guard jpegQuality.isFinite, (0...1).contains(jpegQuality)
			else { throw ArgumentParser.ValidationError("--jpeg-quality must be between 0 and 1.") }
		}
		if let ffmpeg { try requireNonempty(ffmpeg, name: "--ffmpeg") }
		if let archive { try requireNonempty(archive, name: "--archive") }
	}

	internal func preflight() throws {
		if imageWidth != nil { _ = try ffmpegExecutable(path: ffmpeg) }
		if let archive, FileManager.default.fileExists(atPath: archive) {
			throw CLIError.operation("Archive already exists: \(archive)")
		}
	}

	nonisolated(nonsending)
	internal func publish(
		inputs: [PyxisBundleInput],
		to output: URL
	) async throws -> PyxisMapDocument {
		try Task.checkCancellation()
		try preflight()
		let archiveURL: URL? = archive.map { URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath() }
		if let archiveURL {
			for root in inputs.map(\.root) + [output] {
				let directory: String = root.standardizedFileURL.resolvingSymlinksInPath().path
				guard archiveURL.path != directory, !archiveURL.path.hasPrefix(directory + "/")
				else { throw CLIError.operation("Archive must be outside input and output directories.") }
			}
		}

		let document: PyxisMapDocument
		if imageWidth != nil || jpegQuality != nil {
			let scratch: URL = FileManager.default.temporaryDirectory
				.appendingPathComponent("pyxis-images-\(UUID().uuidString)")
			try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
			defer {
				// Cleanup cannot replace the original publication or ffmpeg error.
				try? FileManager.default.removeItem(at: scratch)
			}
			let optimizer: FFmpegImageOptimizer? = try imageWidth.map { width in
				try .init(
					executable: ffmpegExecutable(path: ffmpeg),
					maximumWidth: width,
					scratch: scratch
				)
			}
			var completed: Int = 0
			document = try await BundlePublisher.publish(inputs: inputs, to: output) { asset, bytes in
				var result: PyxisAssetContent = try await optimizer?.optimize(asset: asset, bytes: bytes)
				?? .init(asset: asset, bytes: bytes)
				if let jpegQuality {
					result = try JPEGImageEncoder(quality: jpegQuality).encode(result)
				}
				completed += 1
				if completed.isMultiple(of: 100) { print("Prepared \(completed) images…") }
				return result
			}

		} else {
			document = try await BundlePublisher.publish(inputs: inputs, to: output) { asset, bytes in
				.init(asset: asset, bytes: bytes)
			}
		}

		try Task.checkCancellation()
		if let archiveURL {
			try writeBundleArchive(from: output, to: archiveURL)
			print("Archive: \(archiveURL.path)")
		}
		return document
	}
}
