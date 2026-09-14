import Foundation
import PyxisModel

internal struct RecordingComposition {
	internal init() {}

	internal func compose(
		previous: PyxisMapDocument?,
		incoming: PyxisMapDocument,
		policy: PyxisStorePolicy
	) throws -> PyxisMapDocument {
		guard incoming.format == .map, !incoming.observations.isEmpty,
			incoming.observations.allSatisfy({ $0.status == .passed })
		else { throw PyxisValidationError("Store updates require passed observations; failed and incomplete runs remain separate artifacts") }
		if let previous, Data(previous.project.id.utf8) != Data(incoming.project.id.utf8) {
			throw PyxisValidationError("Recording store belongs to another project")
		}
		var result: PyxisMapDocument = incoming
		result.observations = incoming.observations.map { observation in
			var value: PyxisObservation = observation
			value.runID = observation.runID ?? incoming.run.id
			return value
		}
		guard let previous, policy == .merge else { return try normalized(result) }
		let replacements: Set<String> = try .init(incoming.observations.map { try scope($0, in: incoming) })
		let retained: [PyxisObservation] = try previous.observations.filter {
			try !replacements.contains(scope($0, in: previous))
		}.map { observation in
			var value: PyxisObservation = observation
			value.runID = observation.runID ?? previous.run.id
			return value
		}
		let observationIDs: Set<Data> = .init(retained.map { Data($0.id.utf8) })
		let captures: [PyxisCapture] = previous.captures.filter { observationIDs.contains(Data($0.observationID.utf8)) }
		let transitions: [PyxisTransition] = previous.transitions.filter { observationIDs.contains(Data($0.observationID.utf8)) }
		let stateIDs: Set<Data> = .init((captures.map(\.stateID) + transitions.flatMap { [$0.fromStateID, $0.toStateID] }).map { Data($0.utf8) })
		let states: [PyxisState] = previous.states.filter { stateIDs.contains(Data($0.id.utf8)) }
		let domainIDs: Set<Data> = .init(states.map { Data($0.domainID.utf8) })
		let profileIDs: Set<Data> = .init(retained.map { Data($0.profileID.utf8) })
		let profiles: [PyxisProfile] = previous.profiles.filter { profileIDs.contains(Data($0.id.utf8)) }
		for profile in profiles {
			if let replacement = incoming.profiles.first(where: { Data($0.id.utf8) == Data(profile.id.utf8) }), replacement.requested != profile.requested {
				throw PyxisValidationError("Profile ID changes the meaning of a retained recording: \(profile.id)")
			}
		}
		try requireDisjoint(retained, result.observations, id: \.id)
		try requireDisjoint(captures, incoming.captures, id: \.id)
		try requireDisjoint(transitions, incoming.transitions, id: \.id)
		result.observations = combine(retained, result.observations, id: \.id)
		result.captures = combine(captures, incoming.captures, id: \.id)
		result.transitions = combine(transitions, incoming.transitions, id: \.id)
		result.states = combine(states, incoming.states, id: \.id)
		result.domains = combine(previous.domains.filter { domainIDs.contains(Data($0.id.utf8)) }, incoming.domains, id: \.id)
		result.profiles = combine(profiles, incoming.profiles, id: \.id)
		var runs: [Data: PyxisRunMetadata] = [:]
		for run in [previous.run] + previous.recordingRuns + [incoming.run] + incoming.recordingRuns {
			let key: Data = Data(run.id.utf8)
			if let existing = runs[key], existing != run {
				throw PyxisValidationError("Conflicting recording run: \(run.id)")
			}
			runs[key] = run
		}
		let usedRuns: Set<Data> = .init(result.observations.compactMap(\.runID).map { Data($0.utf8) })
		result.recordingRuns = runs.values.filter { usedRuns.contains(Data($0.id.utf8)) && Data($0.id.utf8) != Data(incoming.run.id.utf8) }
		return try normalized(result)
	}

	private func scope(_ observation: PyxisObservation, in document: PyxisMapDocument) throws -> String {
		guard let profile = document.profiles.first(where: { Data($0.id.utf8) == Data(observation.profileID.utf8) })
		else { throw PyxisValidationError("Missing profile") }
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return try StableID.digest(parts: [
			"store_scope", observation.journeyID, observation.testName,
			String(decoding: encoder.encode(profile.requested), as: UTF8.self),
		])
	}

	private func requireDisjoint<Value>(_ older: [Value], _ newer: [Value], id: KeyPath<Value, String>) throws {
		let keys: Set<Data> = .init(older.map { Data($0[keyPath: id].utf8) })
		guard !newer.contains(where: { keys.contains(Data($0[keyPath: id].utf8)) })
		else { throw PyxisValidationError("Incoming recording reuses an ID owned by a retained scope") }
	}

	private func combine<Value>(_ older: [Value], _ newer: [Value], id: KeyPath<Value, String>) -> [Value] {
		var values: [Data: Value] = [:]
		for value in older + newer { values[Data(value[keyPath: id].utf8)] = value }
		return values.sorted { $0.key.lexicographicallyPrecedes($1.key) }.map(\.value)
	}

	private func normalized(_ document: PyxisMapDocument) throws -> PyxisMapDocument {
		var result: PyxisMapDocument = document
		result.domains = combine([], result.domains, id: \.id)
		result.states = combine([], result.states, id: \.id)
		result.profiles = combine([], result.profiles, id: \.id)
		result.observations = combine([], result.observations, id: \.id)
		result.captures = combine([], result.captures, id: \.id)
		result.transitions = combine([], result.transitions, id: \.id)
		result.recordingRuns = combine([], result.recordingRuns, id: \.id)
		try PyxisValidation.validate(result)
		return result
	}
}
