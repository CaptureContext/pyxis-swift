import CustomDump
import Foundation
import PyxisModel
import PyxisProcessing
import Testing
import ZIPFoundation

@Suite
struct CompositionTests {
	@Test
	func containerConformanceFixtures() throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let directory = workspace.fixture.deletingLastPathComponent().appendingPathComponent("containers")
		for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
			let data = try Data(contentsOf: file)
			let validate: () throws -> Void = {
				let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
				if value["format"] as? String == "pyxis.document" { _ = try PyxisVisualizationDocument(data: data) }
				else { _ = try PyxisArtifact(data: data) }
			}
			if file.lastPathComponent.hasPrefix("valid") { try validate() }
			else { #expect(throws: (any Error).self) { try validate() } }
		}
	}

	@Test
	func nestedChildrenAreIndependentAndCompositionRetainsCrossRunMetadata() throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let first = try workspace.recording("first")
		var second = try workspace.recording("second", appearance: "light")
		second.document.states[0].title = "Updated label"
		let a = workspace.root.appendingPathComponent("a.pyx")
		let b = workspace.root.appendingPathComponent("b.pyx")
		let composed = workspace.root.appendingPathComponent("composed.pyx")
		try PyxisArchive().write(first, to: a)
		try PyxisArchive().write(second, to: b)
		try PyxisArchive().compose([a, b], to: composed)
		let output = workspace.root.appendingPathComponent("out")
		let records = try PyxisArchive().extractRecordings(from: composed, to: output)
		expectNoDifference(records.map { $0.document.run.id }, ["first", "second"])
		expectNoDifference(records[1].document.states[0].title, "Updated label")
		let child = output.appendingPathComponent("recording-1/recording-0/recording-0.pyx")
		let extracted = try PyxisArchive().extractRecordings(from: child, to: workspace.root.appendingPathComponent("child"))
		expectNoDifference(extracted[0].document, second.document)
		let duplicate = workspace.root.appendingPathComponent("duplicate.pyx")
		try PyxisArchive().write(first, to: duplicate)
		try expectNoDifference(Data(contentsOf: duplicate), Data(contentsOf: a))
	}

	@Test
	func documentEmbedsRecordingsAndRejectsDanglingPages() throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let a = workspace.root.appendingPathComponent("a.pyx")
		try PyxisArchive().write(workspace.recording("first"), to: a)
		let refs = try PyxisArchive().references(for: [a])
		var document = PyxisVisualizationDocument(id: "document", title: "App", recordings: refs, pages: [
			.init(id: "release", title: "Release", recordingIDs: [refs[0].id]),
			.init(id: "review", title: "Review", recordingIDs: [refs[0].id]),
		])
		let output = workspace.root.appendingPathComponent("app.pyxis")
		try PyxisArchive().writeDocument(document, sources: [a], to: output)
		let records = try PyxisArchive().extractRecordings(from: output, to: workspace.root.appendingPathComponent("doc"))
		expectNoDifference(records.count, 1)
		document.pages[0].recordingIDs = ["missing"]
		#expect(throws: (any Error).self) { try document.validate() }
	}

	@Test
	func legacyMigrationRequiresOptInAndPreservesSource() throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input = try workspace.recording("legacy")
		let old = workspace.root.appendingPathComponent("old.pyx")
		let archive = try Archive(url: old, accessMode: .create)
		let descriptor = Data(#"{"format":"pyxis.artifact","version":1,"type":"regular"}"#.utf8)
		try archive.addEntry(with: "artifact.json", type: .file, uncompressedSize: Int64(descriptor.count)) { _, _ in descriptor }
		try archive.addEntry(with: "manifest.json", relativeTo: input.root)
		for path in Set(input.document.captures.map(\.asset.path)) { try archive.addEntry(with: path, relativeTo: input.root) }
		let before = try Data(contentsOf: old)
		#expect(throws: (any Error).self) { try PyxisArchive().extractRecordings(from: old, to: workspace.root.appendingPathComponent("implicit")) }
		let migrated = workspace.root.appendingPathComponent("new.pyx")
		try PyxisArchive().migrate(from: old, to: migrated)
		let records = try PyxisArchive().extractRecordings(from: migrated, to: workspace.root.appendingPathComponent("new"))
		expectNoDifference(records[0].document, input.document)
		expectNoDifference(try Data(contentsOf: old), before)
	}

	@Test
	func selectedUpdateIsAtomicWhenOneVariationFails() throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store = PyxisRecordingStore(root: workspace.root.appendingPathComponent("store"))
		let initial = try store.update(workspace.recording("first"))
		let good = try workspace.recording("new")
		var bad = try workspace.recording("bad", appearance: "light")
		bad.document.observations[0].status = .incomplete
		#expect(throws: (any Error).self) { try store.update([good, bad]) }
		expectNoDifference(try store.snapshot()?.id, initial.id)
	}
	@Test
	func storeMigrationPreservesHistoricalRevisionAndSourceBytes() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("legacy-store")
		let source: URL = workspace.root.appendingPathComponent("old-store")
		let output: URL = workspace.root.appendingPathComponent("new-store")
		let manager: FileManager = .default
		for directory in ["assets", "heads", "snapshots", ".runtime"] {
			try manager.createDirectory(
				at: source.appendingPathComponent(directory),
				withIntermediateDirectories: true
			)
		}
		try Data().write(to: source.appendingPathComponent(".runtime/write.lock"))
		let descriptor: Data = try JSONSerialization.data(withJSONObject: [
			"format": "pyxis.store", "version": 1, "project_id": input.document.project.id,
		])
		try descriptor.write(to: source.appendingPathComponent("store.json"))
		let snapshot: Data = try PyxisJSON.encode(input.document)
		let snapshotID: String = StableID.sha256(snapshot)
		let snapshotPath: String = "snapshots/\(snapshotID).json"
		try snapshot.write(to: source.appendingPathComponent(snapshotPath))
		let head: Data = try JSONSerialization.data(withJSONObject: ["snapshot_id": snapshotID])
		try head.write(to: source.appendingPathComponent("heads/default.json"))
		for path in Set(input.document.captures.map(\.asset.path)) {
			try manager.copyItem(
				at: input.root.appendingPathComponent(path),
				to: source.appendingPathComponent(path)
			)
		}

		try PyxisRecordingStore.migrate(from: source, to: output)
		let migrated: PyxisStoredRecording? = try PyxisRecordingStore(root: output).snapshot()
		expectNoDifference(migrated?.id, snapshotID)
		expectNoDifference(migrated?.recordings.first?.document, input.document)
		try expectNoDifference(Data(contentsOf: source.appendingPathComponent("store.json")), descriptor)
		try expectNoDifference(Data(contentsOf: output.appendingPathComponent(snapshotPath)), snapshot)

		let failedOutput: URL = workspace.root.appendingPathComponent("failed-migration")
		try Data("corrupt".utf8).write(to: source.appendingPathComponent(snapshotPath))
		#expect(throws: (any Error).self) {
			try PyxisRecordingStore.migrate(from: source, to: failedOutput)
		}
		#expect(!manager.fileExists(atPath: failedOutput.path))
	}

}
