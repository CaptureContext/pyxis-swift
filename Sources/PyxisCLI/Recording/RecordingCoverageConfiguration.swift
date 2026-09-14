import Foundation

internal struct RecordingCoverageConfiguration: Decodable {
	internal let states: [String]

	internal init(states: [String]) {
		self.states = states
	}

	internal func validate() throws {
		for state in states { try requireNonempty(state, name: "coverage.states") }
		guard Set(states).count == states.count
		else { throw CLIError.operation("Coverage states must be unique.") }
	}
}
