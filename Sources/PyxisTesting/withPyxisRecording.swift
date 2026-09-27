#if canImport(UIKit)
import Foundation
import Testing
import PyxisCore
import PyxisRecording

/// Records one contribution. Include the parameter value in recordingKey for parameterized tests.
/// Export confirms the enclosing native test passed before promoting the incomplete fragment.
@MainActor
public func withPyxisRecording(
	configuration: PyxisSessionConfiguration,
	recordingKey: String,
	journeyID: String,
	title: String,
	report: PyxisBootstrapReport = .init(variants: [:]),
	body: @MainActor (PyxisSnapshotRecorder) async throws -> Void
) async throws {
	guard let test = Test.current else { throw PyxisSnapshotError.outsideTest }
	let session: PyxisRecordingSession = .init(
		configuration: configuration, recordingKey: recordingKey, journeyID: journeyID,
		title: title, testName: test.id.description,
		producer: .init(framework: "swift_testing", captureMethod: "snapshot_testing"),
		report: report,
		attach: { data, name in Attachment.record(data, named: name) }
	)
	try session.checkpoint()
	do {
		let recorder: PyxisSnapshotRecorder = .init(session: session)
		try await body(recorder)
		try Task.checkCancellation()
		try recorder.complete()
		Attachment.record(Data(session.document.observations[0].id.utf8), named: "pyxis-completed-\(session.document.observations[0].id).txt")
	} catch {
		try session.finish(status: .failed, failure: String(describing: error))
		throw error
	}
}
#endif
