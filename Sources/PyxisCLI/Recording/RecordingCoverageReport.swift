import Foundation
import PyxisModel

internal struct RecordingCoverageReport: Encodable {
	internal let profiles: Int
	internal let states: Int
	internal let captures: Int
	internal let problems: [String]
	internal let complete: Bool

	internal init(
		document: PyxisMapDocument,
		configuration: RecordingCoverageConfiguration?,
		plan: RecordingPlan
	) {
		var problems: [String] = []
		for observation in document.observations where observation.status != .passed {
			problems.append("Observation \(observation.id) is \(observation.status.rawValue).")
		}
		for selection in plan.selections {
			let expected: [String: String] = selection.values
			let profiles: [PyxisProfile] = document.profiles.filter { profile in
				expected.allSatisfy { profile.requested[$0.key] == $0.value }
			}
			let observations: [PyxisObservation] = document.observations.filter { observation in
				profiles.contains { $0.id == observation.profileID } && observation.status == .passed
			}
			let summary: String = expected.keys.sorted().map { "\($0)=\(expected[$0] ?? "")" }.joined(separator: ", ")
			if observations.isEmpty { problems.append("Missing passed recording: \(summary)") }
			let observationIDs: Set<String> = .init(observations.map(\.id))
			let captured: Set<String> = .init(document.captures.filter {
				observationIDs.contains($0.observationID)
			}.map(\.stateID))
			let missing: Set<String> = Set(configuration?.states ?? []).subtracting(captured)
			if !missing.isEmpty { problems.append("Missing states [\(missing.sorted().joined(separator: ", "))]: \(summary)") }
			for observation in observations {
				for (key, value) in expected {
					let result: PyxisVariantResult? = observation.variants[key]
					if result?.value != value || ![.applied, .observed].contains(result?.status) {
						problems.append("Unverified \(key) in observation \(observation.id).")
					}
				}
			}
		}
		self.profiles = document.profiles.count
		self.states = document.states.count
		self.captures = document.captures.count
		self.problems = problems
		self.complete = problems.isEmpty && !document.captures.isEmpty
	}
}
