import CustomDump
import Foundation
import PyxisModel
import PyxisProcessing
import Testing
import ZIPFoundation

@Suite
struct RecordingSizeTests {
	@Test
	func metadataExceedingPreviousCapsStillDecodesAndExtracts() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("source")
		var descriptor: Data = try PyxisArtifact().encoded()
		descriptor.append(Data(repeating: 32, count: 1_024 * 1_024))
		expectNoDifference(try PyxisArtifact(data: descriptor), .init())
		try descriptor.write(to: input.root.appendingPathComponent("artifact.json"))
		try BundleValidator.validate(document: input.document, root: input.root)

		var manifest: Data = try PyxisJSON.encode(input.document)
		manifest.append(Data(repeating: 32, count: 64 * 1_024 * 1_024))
		try manifest.write(to: input.root.appendingPathComponent("manifest.json"))
		let source: URL = workspace.root.appendingPathComponent("large.pyx")
		let archive: Archive = try .init(url: source, accessMode: .create)
		try archive.addEntry(with: "artifact.json", relativeTo: input.root, compressionMethod: .deflate)
		try archive.addEntry(with: "manifest.json", relativeTo: input.root, compressionMethod: .deflate)
		for path in Set(input.document.captures.map(\.asset.path)) {
			try archive.addEntry(with: path, relativeTo: input.root)
		}
		let extracted: PyxisBundleInput = try PyxisArchive().extract(
			from: source, to: workspace.root.appendingPathComponent("extracted")
		)
		expectNoDifference(extracted.document, input.document)
	}

	@Test
	func storeMetadataHasNoArtificialByteCap() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("source")
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let saved: PyxisStoredRecording = try store.update(input)
		for (path, padding) in [("store.json", 1_024 * 1_024), ("heads/default.json", 1_024)] {
			let url: URL = store.root.appendingPathComponent(path)
			var bytes: Data = try .init(contentsOf: url)
			bytes.append(Data(repeating: 32, count: padding))
			try bytes.write(to: url)
		}
		expectNoDifference(try store.snapshot()?.id, saved.id)
	}
}
