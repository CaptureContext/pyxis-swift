import Foundation
import PyxisModel

/// Replacement slots contain complete test/configuration evidence, never a flattened cross-run map.
internal struct RecordingComposition {
	internal func variations(_ document: PyxisMapDocument) throws -> [String: PyxisMapDocument] {
		try PyxisValidation.validate(document)
		guard document.format == .map, !document.observations.isEmpty,
			document.observations.allSatisfy({ $0.status == .passed })
		else { throw PyxisValidationError("Store updates require nonempty, passed recordings") }
		let groups = try Dictionary(grouping: document.observations) { try scope($0, in: document) }
		return try groups.mapValues { observations in
			let owners = Set(observations.map { [$0.testName, $0.journeyID, $0.producer?.framework ?? "", $0.producer?.captureMethod ?? ""] })
			guard owners.count == 1 else { throw PyxisValidationError("Multiple producers or tests claim one recording key and configuration") }
			return PyxisArchive.subset(document, observations: observations)
		}
	}
	internal func scope(_ observation: PyxisObservation, in document: PyxisMapDocument) throws -> String {
		guard let profile = document.profiles.first(where: { Data($0.id.utf8) == Data(observation.profileID.utf8) })
		else { throw PyxisValidationError("Missing profile") }
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		let owner: [String] = observation.recordingKey.map { ["recording_scope", $0] }
		?? ["store_scope", observation.journeyID, observation.testName]
		return try StableID.digest(parts: owner + [String(decoding: encoder.encode(profile.requested), as: UTF8.self)])
	}

}
