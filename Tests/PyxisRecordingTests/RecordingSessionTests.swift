import CustomDump
import Foundation
import Testing
import PyxisCore
import PyxisModel
import PyxisRecording

@MainActor
@Suite
struct RecordingSessionTests {
	@Test
	func capturesAndTransitionsShareASequenceAndPreserveFailures() async throws {
		var attachments: [(Data, String)] = []
		let session = makeSession { attachments.append(($0, $1)) }
		let source: PyxisState = .init(id: "source", screenID: "note", domainID: "notes", title: "Note", label: "Empty", order: 0)
		let destination: PyxisState = .init(id: "destination", screenID: "note", domainID: "notes", title: "Note", label: "Filled", order: 1)
		#expect(throws: (any Error).self) { try session.beginTransition(from: source, to: destination, action: "Fill", kind: "state") }
		try session.capture(source, png: Data([1]), width: 2, height: 2)
		let transition = try session.beginTransition(from: source, to: destination, action: "Fill", kind: "state")
		try session.capture(destination, png: Data([2]), width: 2, height: 2)
		try session.succeedTransition(transition)
		expectNoDifference(session.document.captures.map(\.sequence), [0, 2])
		expectNoDifference(session.document.transitions.map(\.sequence), [1])
		try session.fail(CancellationError())
		try session.finish(status: .passed)
		expectNoDifference(session.document.observations[0].status, .failed)
		#expect(throws: (any Error).self) { try session.capture(source, png: Data([1]), width: 2, height: 2) }
		let fragments = attachments.filter { $0.1.hasSuffix(".json") }
		expectNoDifference(try PyxisJSON.decode(#require(fragments.last).0), session.document)
	}

	@Test
	func executionsHaveSeparateIdentitiesAndConflictingStateDeclarationsFail() async throws {
		let first = makeSession { _, _ in }
		let second = makeSession { _, _ in }
		#expect(first.document.observations[0].id != second.document.observations[0].id)
		expectNoDifference(first.document.observations[0].recordingKey, second.document.observations[0].recordingKey)
		var state: PyxisState = .init(id: "a", screenID: "a", domainID: "notes", title: "A", label: "A", order: 0)
		try first.declare(state)
		state.title = "Another meaning"
		#expect(throws: (any Error).self) { try first.declare(state) }
	}

	private func makeSession(attach: @escaping @MainActor (Data, String) throws -> Void) -> PyxisRecordingSession {
		.init(
			configuration: .init(
				project: .init(id: "test", title: "Test"), run: .init(id: "run", createdAt: Date(timeIntervalSince1970: 0)),
				domains: [.init(id: "notes", title: "Notes", order: 0)], profile: .init(id: "default", title: "Default", requested: [:])
			),
			recordingKey: "states.note", journeyID: "note", title: "Note", testName: "test",
			producer: .init(framework: "swift_testing", captureMethod: "snapshot_testing"), attach: attach
		)
	}
}
