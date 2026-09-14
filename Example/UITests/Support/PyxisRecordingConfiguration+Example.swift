import ExampleTesting
import Foundation
import XCTest

extension PyxisRecordingConfiguration {
	internal static func example(
		profile: ExampleProfile,
		journey: ExampleJourney
	) throws -> Self {
		let environment: PyxisRecordingEnvironment = try .init(environment: ProcessInfo.processInfo.environment)
		return try .init(
			project: .init(id: "pyxis.ios-example", title: "Notes · Pyxis example"),
			run: .init(
				id: environment.runID ?? "example-local-v3",
				createdAt: environment.runCreatedAt ?? Date(timeIntervalSince1970: 1789344000),
				provenance: ["fixture": "swiftui-notes-v3", "screenshot_source": "screen"]
			),
			domains: [.notes, .settings],
			profile: profile.recording,
			journeyID: journey.rawValue,
			title: journey.title,
			screenshotSource: .screen
		)
	}

}
