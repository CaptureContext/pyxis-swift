import Foundation
import PyxisModel
import Testing
@testable import pyxis

@Suite
struct RecordingCoverageTests {
	@Test
	func missingStatesAndProfilesMakeTheReportIncomplete() throws {
		var document: PyxisMapDocument = .init(
			project: .init(id: "example", title: "Example"),
			run: .init(id: "run", createdAt: Date(timeIntervalSince1970: 0)),
			profiles: [.init(id: "light", title: "Light", requested: ["device": "Phone", "color_scheme": "light"])],
			observations: [.init(
				id: "tour", journeyID: "tour", title: "Tour", testName: "Tests/testTour", profileID: "light", status: .passed,
				variants: ["device": .init(status: .observed, value: "Phone"), "color_scheme": .init(status: .applied, value: "light")]
			)],
			captures: [.init(id: "home", stateID: "home", observationID: "tour", sequence: 0, asset: .init(path: "assets/home.jpg", mediaType: .jpeg, width: 240, height: 480))]
		)
		var plan: RecordingPlan = .init(devices: [], skipped: [], selections: [
			.init(order: 0, values: ["device": "Phone", "color_scheme": "light"]),
			.init(order: 1, values: ["device": "Phone", "color_scheme": "dark"]),
		])
		let expected: RecordingCoverageConfiguration = .init(states: ["home", "settings"])
		let incomplete = RecordingCoverageReport(document: document, configuration: expected, plan: plan)
		#expect(!incomplete.complete)
		#expect(incomplete.problems.contains { $0.contains("settings") })
		#expect(incomplete.problems.contains { $0.contains("color_scheme=dark") })
		plan = .init(devices: [], skipped: [], selections: [plan.selections[0]])
		let narrow: RecordingCoverageConfiguration = .init(states: ["home"])
		#expect(RecordingCoverageReport(document: document, configuration: narrow, plan: plan).complete)
		document.observations[0].variants["color_scheme"] = .init(status: .unsupported, value: "light")
		#expect(!RecordingCoverageReport(document: document, configuration: narrow, plan: plan).complete)
	}
}
