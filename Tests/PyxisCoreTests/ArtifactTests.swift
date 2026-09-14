import CustomDump
import Foundation
import PyxisModel
import PyxisProcessing
import Testing
import ZIPFoundation

@Suite
struct ArtifactTests {
	@Test
	func roundTripAndMetadataFirst() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("first")
		let output: URL = workspace.root.appendingPathComponent("recording.pyx")
		try PyxisArchive().write(input, to: output)
		let archive: Archive = try .init(url: output, accessMode: .read)
		expectNoDifference(Array(archive).prefix(2).map(\.path), ["artifact.json", "manifest.json"])
		expectNoDifference(Array(archive).count, 3)
		let unpacked: PyxisBundleInput = try PyxisArchive().extract(from: output, to: workspace.root.appendingPathComponent("unpacked"))
		expectNoDifference(unpacked.document, input.document)
		#expect(throws: (any Error).self) { try PyxisArchive().write(input, to: output) }
		#expect(throws: (any Error).self) { try PyxisArchive().extract(from: output, to: unpacked.root) }
	}

	@Test
	func descriptorFixtures() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let directory: URL = workspace.fixture.deletingLastPathComponent().appendingPathComponent("artifact-descriptors")
		for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
			let data: Data = try .init(contentsOf: file)
			if file.lastPathComponent.hasPrefix("valid") {
				expectNoDifference(try PyxisArtifact(data: data), .init())
			} else {
				#expect(throws: (any Error).self) { try PyxisArtifact(data: data) }
			}
		}
	}

	@Test
	func missingDescriptorAndMissingAssetsFailWithoutPublishing() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("source")
		let archiveURL: URL = workspace.root.appendingPathComponent("bad.pyx")
		let archive: Archive = try .init(url: archiveURL, accessMode: .create)
		try archive.addEntry(with: "manifest.json", relativeTo: input.root)
		let output: URL = workspace.root.appendingPathComponent("extracted")
		#expect(throws: (any Error).self) { try PyxisArchive().extract(from: archiveURL, to: output) }
		try archive.addEntry(with: "artifact.json", relativeTo: input.root)
		#expect(throws: (any Error).self) { try PyxisArchive().extract(from: archiveURL, to: output) }
		#expect(!FileManager.default.fileExists(atPath: output.path))
	}

	@Test(arguments: ["../escape", "/absolute", "assets/../escape", "metadata\\escape"])
	func unsafeArchivePathsAreRejected(path: String) async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let archiveURL: URL = workspace.root.appendingPathComponent("bad.pyx")
		let archive: Archive = try .init(url: archiveURL, accessMode: .create)
		try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(1)) { _, _ in Data([0]) }
		#expect(throws: (any Error).self) {
			try PyxisArchive().extract(from: archiveURL, to: workspace.root.appendingPathComponent("output"))
		}
	}

	@Test
	func duplicateAndSymlinkEntriesAreRejected() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		for type in [Entry.EntryType.file, .symlink] {
			let archiveURL: URL = workspace.root.appendingPathComponent(type == .file ? "duplicate.pyx" : "symlink.pyx")
			let archive: Archive = try .init(url: archiveURL, accessMode: .create)
			try archive.addEntry(with: "test", type: type, uncompressedSize: Int64(1)) { _, _ in Data([97]) }
			if type == .file { try archive.addEntry(with: "test", type: type, uncompressedSize: Int64(1)) { _, _ in Data([98]) } }
			#expect(throws: (any Error).self) {
				try PyxisArchive().extract(from: archiveURL, to: workspace.root.appendingPathComponent("output"))
			}
		}
	}
}
