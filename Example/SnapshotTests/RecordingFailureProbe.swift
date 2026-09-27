import Foundation
import UIKit
import Testing
import SnapshotTesting
import ExampleSnapshotTesting

/// Opt-in end-to-end exporter check: all cases intentionally fail without throwing.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PYXIS_VERIFY_NATIVE_FAILURE"] == "1"))
internal struct RecordingFailureProbe {
	@Test(arguments: ["before", "inside", "after"])
	internal func nonthrowingExpectation(position: String) async throws {
		if position == "before" { #expect(position != "before") }
		try await withPyxisRecording(
			configuration: .init(
				project: .init(id: "failure-probe", title: "Failure probe"), run: .init(id: "probe", createdAt: Date(timeIntervalSince1970: 0)),
				domains: [.init(id: "fixture", title: "Fixture", order: 0)], profile: .init(id: "default", title: "Default", requested: [:])
			),
			recordingKey: "probe.\(position)", journeyID: "probe", title: "Nonthrowing failures"
		) { recorder in
			let image: UIImage = UIGraphicsImageRenderer(size: .init(width: 4, height: 4)).image { context in
				UIColor.red.setFill()
				context.fill(.init(x: 0, y: 0, width: 4, height: 4))
			}
			try await recorder.capture(
				.init(id: "fixture", screenID: "fixture", domainID: "fixture", title: "Fixture", label: "Red", order: 0),
				value: image, as: .image
			)
			if position == "inside" { #expect(position != "inside") }
		}
		if position == "after" { #expect(position != "after") }
	}
}
