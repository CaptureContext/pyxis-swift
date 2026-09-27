import CryptoKit
import Foundation

public enum StableID {
	public static func digest(parts: [String]) -> String {
		var bytes = Data()
		for part in parts {
			let value = Data(part.utf8)
			bytes.append(contentsOf: "\(value.count):".utf8)
			bytes.append(value)
		}
		return sha256(bytes)
	}

	public static func observation(
		projectID: String,
		runID: String,
		journeyID: String,
		testName: String,
		profileID: String,
		attempt: Int
	) -> String {
		"o_" + digest(parts: ["observation", projectID, runID, journeyID, testName, profileID, String(attempt)])
	}

	public static func capture(
		observationID: String,
		stateID: String,
		occurrence: Int
	) -> String {
		"c_" + digest(parts: ["capture", observationID, stateID, String(occurrence)])
	}

	public static func transition(observationID: String, sequence: Int) -> String {
		"t_" + digest(parts: ["transition", observationID, String(sequence)])
	}

	public static func sha256(_ data: Data) -> String {
		SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
	}
}
