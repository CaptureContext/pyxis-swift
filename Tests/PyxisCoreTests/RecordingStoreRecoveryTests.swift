import CustomDump
import Darwin
import Foundation
import PyxisModel
import Testing
@testable import PyxisProcessing

@Suite
struct RecordingStoreRecoveryTests {
	@Test
	func simultaneousFirstWritesRetainEveryScope() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("new-store"))
		let inputs: [PyxisBundleInput] = try (0..<8).map {
			try workspace.recording("run_\($0)", journey: "journey_\($0)")
		}
		try await withThrowingTaskGroup(of: Void.self) { group in
			for input in inputs { group.addTask { try store.update(input) } }
			try await group.waitForAll()
		}
		let current: PyxisStoredRecording? = try store.snapshot()
		let snapshot: PyxisStoredRecording = try #require(current)
		expectNoDifference(snapshot.bundle.document.observations.count, inputs.count)
		try BundleValidator.validate(document: snapshot.bundle.document, root: store.root)
	}

	@Test(arguments: ["store.json", "assets", "snapshots", "heads"])
	func diskFullDuringEachWriteKeepsThePreviousHeadAndCanRetry(_ stage: String) async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let baseline: PyxisStoredRecording? = ["snapshots", "heads"].contains(stage)
		? try store.update(workspace.recording("baseline"))
		: nil
		let input: PyxisBundleInput = try workspace.recording("updated")
		let writer: StoreFileWriter = .init { data, temporary, destination in
			if destination.lastPathComponent == stage || destination.deletingLastPathComponent().lastPathComponent == stage {
				// Model an actual partial file, then the OS reporting exhausted disk space.
				try Data(data.prefix(8)).write(to: temporary, options: .withoutOverwriting)
				throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
			}
			try data.write(to: temporary, options: .withoutOverwriting)
		}
		do {
			try store.update(input, writer: writer)
			Issue.record("The injected disk-full write succeeded")
		} catch {
			expectNoDifference((error as NSError).domain, NSPOSIXErrorDomain)
			expectNoDifference((error as NSError).code, Int(ENOSPC))
		}
		if let baseline {
			expectNoDifference(try store.snapshot()?.id, baseline.id)
			try BundleValidator.validate(document: baseline.bundle.document, root: store.root)
		} else {
			#expect(!FileManager.default.fileExists(atPath: store.root.appendingPathComponent("heads/default.json").path))
		}
		expectNoDifference(try FileManager.default.contentsOfDirectory(atPath: store.root.appendingPathComponent(".runtime/staging").path), [])
		let retried: PyxisStoredRecording = try store.update(input)
		expectNoDifference(retried.bundle.document.run.id, "updated")
		try BundleValidator.validate(document: retried.bundle.document, root: store.root)
	}

	@Test(arguments: [false, true])
	func interruptedStagingIsRecoveredWithoutPruningHistory(_ initialized: Bool) async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let baseline: PyxisStoredRecording? = initialized ? try store.update(workspace.recording("baseline")) : nil
		let staging: URL = store.root.appendingPathComponent(".runtime/staging")
		try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
		let abandoned: URL = staging.appendingPathComponent("00000000-0000-0000-0000-000000000001.tmp")
		try Data("interrupted write".utf8).write(to: abandoned)
		if let baseline { expectNoDifference(try store.snapshot()?.id, baseline.id) }
		let result: PyxisStoredRecording = try store.update(workspace.recording("next"))
		#expect(!FileManager.default.fileExists(atPath: abandoned.path))
		expectNoDifference(try store.snapshot()?.id, result.id)
		if let baseline { expectNoDifference(try store.snapshot(id: baseline.id).id, baseline.id) }
	}

	@Test
	func recoveryRejectsStagingSymlinksAndPreservesTheirTargets() async throws {
		let workspace: ArtifactTestWorkspace = try .init()
		let input: PyxisBundleInput = try workspace.recording("input")
		let store: PyxisRecordingStore = .init(root: workspace.root.appendingPathComponent("store"))
		let baseline: PyxisStoredRecording = try store.update(input)
		let personal: URL = workspace.root.appendingPathComponent("personal.txt")
		try Data("keep".utf8).write(to: personal)
		let link: URL = store.root.appendingPathComponent(".runtime/staging/00000000-0000-0000-0000-000000000001.tmp")
		try FileManager.default.createSymbolicLink(at: link, withDestinationURL: personal)
		#expect(throws: (any Error).self) { try store.update(input) }
		expectNoDifference(try String(contentsOf: personal, encoding: .utf8), "keep")
		expectNoDifference(try store.snapshot()?.id, baseline.id)
	}
}
