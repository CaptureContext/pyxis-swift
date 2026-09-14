import Foundation

public enum PyxisValidation {
	public static let maximumInteger: Int = 9_007_199_254_740_991

	public static func validate(
		_ document: PyxisMapDocument,
		requireAssetHashes: Bool? = nil
	) throws {
		guard document.version == 1
		else { throw PyxisValidationError("Unsupported format version") }

		try nonempty(
			document.project.id,
			"project.id"
		)

		try nonempty(
			document.project.title,
			"project.title"
		)

		try nonempty(
			document.run.id,
			"run.id"
		)

		try ISO8601Timestamp.validate(document.run.createdAt)

		for key in document.run.provenance.keys {
			try nonempty(key, "provenance key")
		}

		let runs = try index([document.run] + document.recordingRuns, id: \.id)
		for run in document.recordingRuns {
			try ISO8601Timestamp.validate(run.createdAt)
			for key in run.provenance.keys { try nonempty(key, "provenance key") }
		}

		if document.format == .fragment, document.observations.count != 1 {
			throw PyxisValidationError("Fragments require exactly one observation")
		}

		let domains = try index(document.domains, id: \.id)
		let states = try index(document.states, id: \.id)
		let profiles = try index(document.profiles, id: \.id)

		let observations = try index(document.observations, id: \.id)
		_ = try index(document.captures, id: \.id)
		_ = try index(document.transitions, id: \.id)

		for domain in document.domains {
			try nonempty(domain.title, "domain.title")
			try integer(domain.order, minimum: 0)
		}

		for state in document.states {
			try nonempty(state.screenID, "state.screen_id")
			try nonempty(state.title, "state.title")

			for key in state.metadata.keys {
				try nonempty(key, "metadata key")
			}

			try integer(state.order, minimum: 0)
			try reference(state.domainID, in: domains, name: "state.domain_id")
		}

		for profile in document.profiles {
			try nonempty(profile.title, "profile.title")
			try integer(profile.order, minimum: 0)
			for key in profile.requested.keys {
				try nonempty(key, "variant key")
			}
		}

		for observation in document.observations {
			if let runID = observation.runID {
				try reference(runID, in: runs, name: "observation.run_id")
			}
			try nonempty(
				observation.journeyID,
				"observation.journey_id"
			)

			try nonempty(
				observation.title,
				"observation.title"
			)

			try nonempty(
				observation.testName,
				"observation.test_name"
			)

			try reference(
				observation.profileID,
				in: profiles,
				name: "observation.profile_id"
			)

			if let startedAt = observation.startedAt {
				try ISO8601Timestamp.validate(startedAt)
			}

			let requested = profiles[key(observation.profileID)]!.requested
			let resultKeys = Set(observation.variants.keys.map(key))

			for request in requested.keys where !resultKeys.contains(key(request)) {
				throw PyxisValidationError("Missing variant result for \(request)")
			}

			for (variant, result) in observation.variants {
				try nonempty(variant, "variant key")
				switch result.status {
				case .applied, .observed:
					if result.value == nil { throw PyxisValidationError("Applied/observed variant requires value") }
				case .unsupported, .unverified:
					if result.reason == nil { throw PyxisValidationError("Unsupported/unverified variant requires reason") }
				}
			}
		}

		var sequences: [Data: Set<Int>] = [:]
		var descriptors: [Data: PyxisAsset] = [:]
		for capture in document.captures {
			try reference(
				capture.stateID,
				in: states,
				name: "capture.state_id"
			)

			try reference(
				capture.observationID,
				in: observations,
				name: "capture.observation_id"
			)

			try addSequence(
				capture.sequence,
				observationID: capture.observationID,
				to: &sequences
			)

			try validateAsset(
				capture.asset,
				requireHash: requireAssetHashes ?? (document.format == .map)
			)

			let pathKey = key(capture.asset.path)

			if let previous = descriptors[pathKey], previous != capture.asset {
				throw PyxisValidationError("Conflicting asset descriptors for \(capture.asset.path)")
			}
			descriptors[pathKey] = capture.asset
		}

		for transition in document.transitions {
			try reference(
				transition.observationID,
				in: observations,
				name: "transition.observation_id"
			)

			try reference(
				transition.fromStateID,
				in: states,
				name: "transition.from_state_id"
			)

			try reference(
				transition.toStateID,
				in: states,
				name: "transition.to_state_id"
			)

			try nonempty(
				transition.action,
				"transition.action"
			)

			try nonempty(
				transition.kind,
				"transition.kind"
			)

			try addSequence(
				transition.sequence,
				observationID: transition.observationID,
				to: &sequences
			)

			let captures = document.captures
				.filter { key($0.observationID) == key(transition.observationID) }

			guard
				captures.contains(where: {
					key($0.stateID) == key(transition.fromStateID) && $0.sequence < transition.sequence
				})
			else { throw PyxisValidationError("Transition source was not captured earlier") }

			switch transition.status {
			case .succeeded:
				guard
					captures.contains(where: {
						key($0.stateID) == key(transition.toStateID) && $0.sequence > transition.sequence
					})
				else { throw PyxisValidationError("Succeeded transition has no later destination capture") }

			case .failed:
				guard observations[key(transition.observationID)]!.status != .passed
				else { throw PyxisValidationError("Passing observation contains failed transition") }
			}
		}
	}

	public static func validateAsset(_ asset: PyxisAsset, requireHash: Bool) throws {
		try validatePath(asset.path)
		try integer(asset.width, minimum: 1)
		try integer(asset.height, minimum: 1)

		if let hash = asset.sha256 {
			guard hash.utf8.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) })
			else { throw PyxisValidationError("Invalid lowercase SHA-256") }
		} else if requireHash {
			throw PyxisValidationError("Published asset requires SHA-256")
		}
	}

	public static func validatePath(_ path: String) throws {
		let segments = path.split(separator: "/", omittingEmptySubsequences: false)

		guard segments.count >= 2, segments.first == "assets"
		else { throw PyxisValidationError("Asset path must start with assets/") }

		for segment in segments {
			guard !segment.isEmpty, segment != ".", segment != "..", segment.utf8.allSatisfy({
				(65...90).contains($0) || (97...122).contains($0)
				|| (48...57).contains($0) || [45, 46, 95].contains($0)
			}) else { throw PyxisValidationError("Unsafe asset path: \(path)") }
		}
	}

	private static func key(_ string: String) -> Data { Data(string.utf8) }

	private static func index<Value>(
		_ values: [Value],
		id: KeyPath<Value, String>
	) throws -> [Data: Value] {
		var result: [Data: Value] = [:]
		for value in values {
			let identifier = value[keyPath: id]
			try nonempty(identifier, "record.id")

			guard result.updateValue(value, forKey: key(identifier)) == nil
			else { throw PyxisValidationError("Duplicate record ID: \(identifier)") }
		}
		return result
	}

	private static func reference<Value>(
		_ identifier: String,
		in values: [Data: Value],
		name: String
	) throws {
		guard values[key(identifier)] != nil
		else { throw PyxisValidationError("Missing reference \(name): \(identifier)") }
	}

	private static func nonempty(_ value: String, _ name: String) throws {
		guard !value.isEmpty else { throw PyxisValidationError("Empty \(name)") }
	}

	private static func integer(_ value: Int, minimum: Int) throws {
		guard value >= minimum, value <= maximumInteger
		else { throw PyxisValidationError("Integer outside interoperable bounds") }
	}


	private static func addSequence(
		_ sequence: Int,
		observationID: String,
		to sequences: inout [Data: Set<Int>]
	) throws {
		try integer(sequence, minimum: 0)
		guard sequences[key(observationID), default: []].insert(sequence).inserted
		else { throw PyxisValidationError("Duplicate observation sequence") }
	}
}
