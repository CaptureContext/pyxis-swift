import ArgumentParser
import Foundation
import PyxisModel
import PyxisProcessing
import Testing
@testable import pyxis

@Suite
struct OptimizationTests {
	@Test
	func invalidJPEGQualityIsRejectedBeforeExecution() async throws {
		for quality in ["-0.1", "1.1", "nan", "inf", "invalid"] {
			#expect(throws: (any Error).self) {
				try ExportCommand.parse([
					"--xcresult", "run.xcresult", "--output", "map", "--jpeg-quality", quality,
				])
			}
		}
		for quality in ["0", "0.5", "1"] {
			let options: PublicationOptions = try .parse(["--jpeg-quality", quality])
			#expect(options.jpegQuality == Double(quality))
		}
	}

	@Test
	func jpegConversionPreservesDimensionsAndRecordsWithoutFFmpeg() async throws {
		let source: URL = fixtureRoot()
		let input: PyxisBundleInput = try loadBundleInput(source.path)
		let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try! FileManager.default.removeItem(at: folder) }
		let output: URL = folder.appendingPathComponent("jpeg")
		let options: PublicationOptions = try .parse([
			"--jpeg-quality", "0.5", "--ffmpeg", "/nonexistent/ffmpeg",
		])
		let published: PyxisMapDocument = try await options.publish(inputs: [input], to: output)
		try BundleValidator.validate(document: published, root: output)
		var expected: PyxisMapDocument = try MapMerger.merge([input.document])
		for index in expected.captures.indices {
			let asset: PyxisAsset = published.captures[index].asset
			#expect(asset.mediaType == .jpeg)
			#expect(asset.width == expected.captures[index].asset.width)
			#expect(asset.height == expected.captures[index].asset.height)
			#expect(asset.path.hasSuffix(".jpg"))
			expected.captures[index].asset = asset
		}
		#expect(try PyxisJSON.encode(expected) == PyxisJSON.encode(published))
		#expect(Set(published.captures.map(\.asset.path)).count == 1)
	}

	@Test
	func invalidDimensionsAreRejectedBeforeExecution() async throws {
		for width in ["0", "-1", "1.5"] {
			#expect(throws: (any Error).self) {
				try OptimizeCommand.parse(["recording", "--output", "optimized", "--image-width", width])
			}
			#expect(throws: (any Error).self) {
				try MergeCommand.parse(["recording", "--output", "optimized", "--image-width", width])
			}
		}
		let command: OptimizeCommand = try .parse(["recording", "--output", "optimized"])
		#expect(command.publication.imageWidth == 320)
		let large: OptimizeCommand = try .parse([
			"recording", "--output", "optimized", "--image-width", "32768",
		])
		#expect(large.publication.imageWidth == 32768)
	}

	@Test
	func absentFFmpegFailsBeforeWriting() async throws {
		let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		var options: PublicationOptions = try .parse(["--image-width", "1"])
		options.ffmpeg = folder.appendingPathComponent("missing-ffmpeg").path
		await #expect(throws: (any Error).self) {
			try await options.publish(inputs: [], to: folder.appendingPathComponent("output"))
		}
		#expect(!FileManager.default.fileExists(atPath: folder.path))
		#expect(throws: (any Error).self) { try ffmpegExecutable(path: nil, environment: ["PATH": ""]) }
	}

	@Test
	func failedImageProcessingPreservesExistingPublication() async throws {
		let source: URL = fixtureRoot()
		let input: PyxisBundleInput = try loadBundleInput(source.path)
		let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try! FileManager.default.removeItem(at: folder) }
		let output: URL = folder.appendingPathComponent("map")
		let previous: PyxisMapDocument = try BundlePublisher.publish(inputs: [input], to: output)
		let options: PublicationOptions = try .parse(["--image-width", "1", "--ffmpeg", "/usr/bin/false"])
		await #expect(throws: (any Error).self) { try await options.publish(inputs: [input], to: output) }
		try BundleValidator.validate(document: previous, root: output)
		#expect(try PyxisJSON.encode(previous) == Data(contentsOf: output.appendingPathComponent("manifest.json")))
		let files: [String] = try FileManager.default.contentsOfDirectory(atPath: folder.path)
		#expect(files == ["map"])
	}

	@Test
	func realFFmpegProducesValidatedImagesAndPreservesAllRecords() async throws {
		let executable: URL
		do { executable = try ffmpegExecutable(path: nil) }
		catch { return } // ffmpeg is optional on machines running the package's unit tests.
		let source: URL = fixtureRoot()
		let input: PyxisBundleInput = try loadBundleInput(source.path)
		let original: Data = try Data(contentsOf: source.appendingPathComponent("assets/example.png"))
		let folder: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try! FileManager.default.removeItem(at: folder) }
		let output: URL = folder.appendingPathComponent("optimized")
		let archive: URL = folder.appendingPathComponent("shared.pyxis.zip")
		let options: PublicationOptions = try .parse([
			"--image-width", "1", "--ffmpeg", executable.path, "--archive", archive.path,
		])
		let published: PyxisMapDocument = try await options.publish(inputs: [input], to: output)
		try BundleValidator.validate(document: published, root: output)
		#expect(published.captures.count == input.document.captures.count)
		#expect(published.captures.allSatisfy { $0.asset.width == 1 && $0.asset.height == 1 })
		#expect(Set(published.captures.map(\.asset.path)).count == 1)
		#expect(try Data(contentsOf: source.appendingPathComponent("assets/example.png")) == original)
		var expected: PyxisMapDocument = try MapMerger.merge([input.document])
		for index in expected.captures.indices { expected.captures[index].asset = published.captures[index].asset }
		#expect(try PyxisJSON.encode(expected) == PyxisJSON.encode(published))
		#expect(FileManager.default.fileExists(atPath: archive.path))
		await #expect(throws: (any Error).self) { try await options.publish(inputs: [input], to: output) }
	}

	@Test
	func requestedWidthNeverUpscalesImages() async throws {
		let source: URL = fixtureRoot()
		let input: PyxisBundleInput = try loadBundleInput(source.path)
		let asset: PyxisAsset = try #require(input.document.captures.first?.asset)
		let bytes: Data = try BundleValidator.assetData(asset, root: source)
		let optimizer: FFmpegImageOptimizer = .init(
			executable: URL(fileURLWithPath: "/nonexistent/ffmpeg"),
			maximumWidth: 320,
			scratch: URL(fileURLWithPath: "/nonexistent/scratch")
		)
		let result: PyxisAssetContent = try await optimizer.optimize(asset: asset, bytes: bytes)
		#expect(result.asset == asset)
		#expect(result.bytes == bytes)
	}

	private func fixtureRoot() -> URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Format/Fixtures/valid-map")
	}
}
