import CustomDump
import Foundation
import PyxisModel
import PyxisProcessing
import Testing

@Suite
struct RecordingStoreTests {
	@Test
	func explicitRecordingKeysCombineProducersAndAllowDeliberateReplacement() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("mixed"))
		var ui = try workspace.recording("ui")
		ui.document.observations[0].recordingKey = "journey.notes"
		ui.document.observations[0].producer = .init(framework: "xctest", captureMethod: "screen")
		var unit = try workspace.recording("unit")
		unit.document.observations[0].recordingKey = "states.notes"
		unit.document.observations[0].producer = .init(framework: "swift_testing", captureMethod: "snapshot_testing")
		var ambiguous = ui
		var duplicate = ui.document.observations[0]
		duplicate.id = "other_owner"
		duplicate.testName = "differentTest"
		ambiguous.document.observations.append(duplicate)
		#expect(throws: (any Error).self) { try store.update(ambiguous) }
		_ = try store.update(ui)
		let combined = try store.update(unit)
		expectNoDifference(Set(combined.recordings.flatMap { $0.document.observations }.compactMap(\.recordingKey)), ["journey.notes", "states.notes"])
		var replacement = try workspace.recording("replacement", journey: "renamed")
		replacement.document.observations[0].recordingKey = "journey.notes"
		replacement.document.observations[0].producer = unit.document.observations[0].producer
		let replaced = try store.update(replacement)
		expectNoDifference(Set(replaced.recordings.flatMap { $0.document.observations }.map(\.id)), ["o_replacement", "o_unit"])
		var conflict = try workspace.recording("conflict")
		conflict.document.observations[0].recordingKey = "new.scope"
		conflict.document.states[0].title = "Different state meaning"
		let withNewLabels = try store.update(conflict)
		expectNoDifference(withNewLabels.recordings.count, 3)
		expectNoDifference(try store.snapshot(id: replaced.id).recordings.count, 2)
		#expect(withNewLabels.recordings.contains { $0.document.states[0].title == "Different state meaning" })
		#expect(withNewLabels.recordings.contains { $0.document.states[0].title != "Different state meaning" })
	}

	@Test
	func selectiveUpdatesRetainVariantsAndOriginalProvenance() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("external-store"))
		let dark: PyxisBundleInput = try workspace.recording("dark_1")
		let light: PyxisBundleInput = try workspace.recording("light_1", appearance: "light")
		let darkAgain: PyxisBundleInput = try workspace.recording("dark_2")
		let first = try store.update(dark)
		_ = try store.update(light)
		let combined = try store.update(darkAgain)
		expectNoDifference(Set(combined.recordings.flatMap { $0.document.observations }.map(\.id)), ["o_dark_2", "o_light_1"])
		expectNoDifference(combined.recordings.flatMap { $0.document.captures }.count, 6)
		let retained = try #require(combined.recordings.flatMap { $0.document.observations }.first { $0.id == "o_light_1" })
		let retainedDocument = try #require(combined.recordings.first { $0.document.observations.contains { $0.id == retained.id } }).document
		expectNoDifference(retainedDocument.recordingRun(for: retained), light.document.run)
		expectNoDifference(Set(combined.recordings.map { $0.document.run.id }), ["dark_2", "light_1"])
		expectNoDifference(try FileManager.default.contentsOfDirectory(atPath: store.root.appendingPathComponent("assets").path).count, 1)
		expectNoDifference(try store.snapshot(id: first.id).recordings.flatMap { $0.document.observations }.count, 1)
		expectNoDifference(try store.update(darkAgain).id, combined.id)
		try PyxisArchive().write(combined.recordings, to: workspace.root.appendingPathComponent("combined.pyx"))
		let exported = try PyxisArchive().extractRecordings(from: workspace.root.appendingPathComponent("combined.pyx"), to: workspace.root.appendingPathComponent("round-trip"))
		expectNoDifference(Set(exported.map { $0.document.run.id }), ["dark_2", "light_1"])
	}

	@Test
	func contextsAndUpdatePolicyAreExplicit() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let first = try store.update(workspace.recording("first"), context: "main")
		_ = try store.update(workspace.recording("feature", appearance: "light"), context: "feature")
		expectNoDifference(try store.snapshot(context: "main")?.id, first.id)
		#expect(try store.snapshot(context: "default") == nil)
		_ = try store.update(workspace.recording("light", appearance: "light"), context: "main")
		let replaced = try store.update(workspace.recording("replacement"), context: "main", policy: .update)
		expectNoDifference(replaced.recordings.flatMap { $0.document.observations }.map(\.id), ["o_replacement"])
		expectNoDifference(try store.snapshot(id: first.id).id, first.id)
		#expect(throws: (any Error).self) { try store.snapshot(context: "../escape") }
	}

	@Test
	func failuresAndCorruptAssetsDoNotAdvanceTheStore() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let first = try store.update(workspace.recording("first"))
		var bad = try workspace.recording("bad")
		bad.document.observations[0].status = .failed
		#expect(throws: (any Error).self) { try store.update(bad) }
		bad.document.observations[0].status = .passed
		try Data([0]).write(to: bad.root.appendingPathComponent(bad.document.captures[0].asset.path))
		#expect(throws: (any Error).self) { try store.update(bad) }
		expectNoDifference(try store.snapshot()?.id, first.id)
		for input in first.recordings { try BundleValidator.validate(document: input.document, root: input.root) }
	}

	@Test
	func unrelatedFilesProjectsAndSymlinksArePreserved() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input = try workspace.recording("input")
		let directory = workspace.root.appendingPathComponent("personal")
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try Data("notes".utf8).write(to: directory.appendingPathComponent("notes.txt"))
		#expect(throws: (any Error).self) { try PyxisRecordingStore(root: directory).update(input) }
		expectNoDifference(try String(contentsOf: directory.appendingPathComponent("notes.txt"), encoding: .utf8), "notes")
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let first = try store.update(input)
		var unrelated = input
		unrelated.document.project.id = "other"
		#expect(throws: (any Error).self) { try store.update(unrelated) }
		expectNoDifference(try store.snapshot()?.id, first.id)
		try FileManager.default.createSymbolicLink(at: store.root.appendingPathComponent("heads/evil.json"), withDestinationURL: directory.appendingPathComponent("notes.txt"))
		#expect(throws: (any Error).self) { try store.update(input, context: "evil") }
		expectNoDifference(try String(contentsOf: directory.appendingPathComponent("notes.txt"), encoding: .utf8), "notes")
	}

	@Test
	func concurrentUpdatesKeepBothScopes() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		_ = try store.update(workspace.recording("baseline"))
		let inputs = try [workspace.recording("light", appearance: "light"), workspace.recording("settings", journey: "settings")]
		try await withThrowingTaskGroup(of: Void.self) { group in
			for input in inputs { group.addTask { try store.update(input) } }
			try await group.waitForAll()
		}
		expectNoDifference(try store.snapshot()?.recordings.flatMap { $0.document.observations }.count, 3)
	}
}
