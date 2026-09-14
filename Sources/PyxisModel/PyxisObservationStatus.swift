import Foundation

public enum PyxisObservationStatus: String, Codable, Sendable {
	case passed = "passed"
	case failed = "failed"
	case incomplete = "incomplete"
}
