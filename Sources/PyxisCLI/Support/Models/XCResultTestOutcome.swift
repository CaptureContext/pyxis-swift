import PyxisModel

/// Repeated/parameterized executions are promoted only when every reported execution passed.
/// An aggregate pass after a failed retry is insufficient evidence for an individual attachment.
internal struct XCResultTestOutcome: Decodable {
	internal var testResult: String
	internal var testRuns: [Node]

	internal func status(completed: Bool) -> PyxisObservationStatus {
		let results: [String] = testRuns.flatMap(\.executionResults)
		if testResult == "Failed" || results.contains("Failed") { return .failed }
		guard completed, testResult == "Passed", !results.isEmpty,
			results.allSatisfy({ $0 == "Passed" })
		else { return .incomplete }
		return .passed
	}

	internal struct Node: Decodable {
		internal var nodeType: String
		internal var result: String?
		internal var children: [Node]?

		internal var executionResults: [String] {
			var results: [String] = result.map { [$0] } ?? []
			if result == nil, nodeType == "Test Case Run" { results.append("unknown") }
			return results + (children ?? []).flatMap(\.executionResults)
		}
	}
}
