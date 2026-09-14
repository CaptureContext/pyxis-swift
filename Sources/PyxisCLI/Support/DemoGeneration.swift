import Foundation
import PyxisModel
import PyxisProcessing

internal func generateDemo(to output: URL) throws {
	let scratch: URL = FileManager.default.temporaryDirectory
	.appendingPathComponent("pyxis-demo-\(UUID().uuidString)")

	try FileManager.default.createDirectory(
		at: scratch.appendingPathComponent("assets"),
		withIntermediateDirectories: true
	)

	defer {
		// Removing temporary inputs is best effort and must not mask a publication error.
		try? FileManager.default.removeItem(at: scratch)
	}

	let project: PyxisProject = .init(id: "pyxis.demo", title: "Pyxis example")
	let run: PyxisRunMetadata = .init(
		id: "synthetic-v1",
		createdAt: Date(timeIntervalSince1970: 1_789_214_400),
		provenance: ["producer": "pyxis demo", "fixture": "synthetic-v1"]
	)
	let domain: PyxisDomain = .init(id: "main", title: "Example", order: 0)
	let states: [PyxisState] = [
		.init(
			id: "home",
			screenID: "home",
			domainID: "main",
			title: "Home",
			label: "Overview",
			order: 0
		),
		.init(
			id: "detail",
			screenID: "detail",
			domainID: "main",
			title: "Detail",
			label: "Active subscription",
			order: 1
		),
		.init(
			id: "settings",
			screenID: "settings",
			domainID: "main",
			title: "Settings",
			label: "Preferences",
			order: 2
		),
	]
	var inputs: [PyxisBundleInput] = []

	for appearance in ["light", "dark"] {
		let profile: PyxisProfile = .init(
			id: appearance,
			title: appearance.capitalized,
			requested: [
				"color_scheme": appearance,
				"subscription.status": "trial",
				"accessibility.color_filters": "grayscale",
			]
		)
		let observationID: String = StableID.observation(
			projectID: project.id,
			runID: run.id,
			journeyID: "tour",
			testName: "syntheticTour",
			profileID: profile.id,
			attempt: 0
		)
		var fragment: PyxisMapDocument = .init(
			format: .fragment,
			project: project,
			run: run,
			domains: [domain],
			states: states,
			profiles: [profile],
			observations: [
				.init(
					id: observationID,
					journeyID: "tour",
					title: "Explore the example",
					testName: "syntheticTour",
					profileID: profile.id,
					status: .passed,
					variants: [
						"color_scheme": .init(status: .applied, value: appearance),
						"subscription.status": .init(status: .applied, value: "trial"),
						"accessibility.color_filters": .init(
							status: .unsupported,
							reason: "Synthetic fixture does not emulate display color filters."
						),
					]
				),
			]
		)
		let journey: [PyxisState] = [states[0], states[1], states[0], states[2]]

		for (index, state) in journey.enumerated() {
			let occurrence: Int = fragment.captures.filter { $0.stateID == state.id }.count
			let id: String = StableID.capture(
				observationID: observationID,
				stateID: state.id,
				occurrence: occurrence
			)
			let path: String = "assets/\(id).png"
			try drawDemoScreen(
				title: state.title,
				appearance: appearance,
				to: scratch.appendingPathComponent(path)
			)

			if index > 0 {
				let sequence: Int = index * 2 - 1
				fragment.transitions.append(
					.init(
						id: StableID.transition(
							observationID: observationID,
							sequence: sequence
						),
						observationID: observationID,
						fromStateID: journey[index - 1].id,
						toStateID: state.id,
						action: "Open \(state.title)",
						kind: "navigation",
						sequence: sequence,
						status: .succeeded
					)
				)
			}

			fragment.captures.append(
				.init(
					id: id,
					stateID: state.id,
					observationID: observationID,
					sequence: index * 2,
					asset: .init(
						path: path,
						mediaType: .png,
						width: 390,
						height: 844
					)
				)
			)
		}

		inputs.append(.init(document: fragment, root: scratch))
	}

	var failed: PyxisMapDocument = inputs[1].document
	let observationID: String = StableID.observation(
		projectID: project.id,
		runID: run.id,
		journeyID: "failure",
		testName: "syntheticFailure",
		profileID: "dark",
		attempt: 0
	)
	failed.observations[0].id = observationID
	failed.observations[0].journeyID = "failure"
	failed.observations[0].testName = "syntheticFailure"
	failed.observations[0].title = "An interrupted journey"
	failed.observations[0].status = .failed
	failed.observations[0].failure = "Demonstration of a retained failed transition."
	failed.captures = [failed.captures[0]]
	failed.captures[0].id = StableID.capture(
		observationID: observationID,
		stateID: "home",
		occurrence: 0
	)
	failed.captures[0].observationID = observationID
	failed.transitions = [
		.init(
			id: StableID.transition(observationID: observationID, sequence: 1),
			observationID: observationID,
			fromStateID: "home",
			toStateID: "settings",
			action: "Open Settings",
			kind: "navigation",
			sequence: 1,
			status: .failed,
			failure: "Settings did not become ready."
		),
	]
	inputs.append(.init(document: failed, root: scratch))

	let document: PyxisMapDocument = try BundlePublisher.publish(inputs: inputs, to: output)
	print("Generated synthetic example: \(document.captures.count) captures, \(document.observations.count) observations at \(output.path)")
}
