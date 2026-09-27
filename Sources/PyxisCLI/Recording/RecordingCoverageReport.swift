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
		plan: RecordingPlan,
		testSelectors: [String] = []
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
			for selector in testSelectors where !observations.contains(where: { Self.matches($0.testName, selector: selector) }) {
				problems.append("Missing recording output for selected tests \(selector): \(summary)")
			}
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
	private static func matches(_ name: String, selector: String) -> Bool {
		let selection = selector.split(separator: "/").map(String.init)
		// XCTest names omit the target; Swift Testing IDs include it. Match the authored suffix.
		let suffix = selection.count > 1 ? Array(selection.dropFirst()) : selection
		let normalized = name.replacingOccurrences(of: "-[", with: "").replacingOccurrences(of: "]", with: "")
			.replacingOccurrences(of: ".", with: "/").replacingOccurrences(of: " ", with: "/")
		let components = normalized.split(separator: "/").map { String($0.prefix { $0 != "(" }) }
		let wanted = suffix.map { String($0.prefix { $0 != "(" }) }
		guard !wanted.isEmpty, components.count >= wanted.count else { return false }
		return (0...(components.count - wanted.count)).contains { index in Array(components[index..<(index + wanted.count)]) == wanted }
	}

}
