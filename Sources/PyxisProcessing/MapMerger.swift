import Foundation
import PyxisModel

public enum MapMerger {
	/// Combine record sets; raw asset checksums are completed by BundlePublisher before distribution.
	public static func merge(_ documents: [PyxisMapDocument]) throws -> PyxisMapDocument {
		guard let first = documents.first
		else { throw PyxisValidationError("No fragments to merge") }

		for document in documents {
			try PyxisValidation.validate(document)
			guard
				try equal(document.project, first.project),
				try equal(document.run, first.run)
			else { throw PyxisValidationError("Fragments disagree on project or run") }
		}

		let merged = try PyxisMapDocument(
			project: first.project,
			run: first.run,
			domains: records(documents.flatMap(\.domains), id: \.id),
			states: records(documents.flatMap(\.states), id: \.id),
			profiles: records(documents.flatMap(\.profiles), id: \.id),
			observations: records(documents.flatMap(\.observations), id: \.id),
			captures: records(documents.flatMap(\.captures), id: \.id),
			transitions: records(documents.flatMap(\.transitions), id: \.id),
			recordingRuns: records(documents.flatMap(\.recordingRuns), id: \.id)
		)

		try PyxisValidation.validate(merged, requireAssetHashes: false)
		return merged
	}

	private static func records<Value: Encodable>(
		_ values: [Value],
		id: KeyPath<Value, String>
	) throws -> [Value] {
		var index: [Data: Value] = [:]
		for value in values {
			let key = Data(value[keyPath: id].utf8)
			if let previous = index[key], try !equal(previous, value) {
				throw PyxisValidationError("Conflicting record: \(value[keyPath: id])")
			}
			index[key] = value
		}
		return index.sorted { $0.key.lexicographicallyPrecedes($1.key) }.map(\.value)
	}

	private static func equal<Value: Encodable>(_ lhs: Value, _ rhs: Value) throws -> Bool {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(lhs) == encoder.encode(rhs)
	}
}
