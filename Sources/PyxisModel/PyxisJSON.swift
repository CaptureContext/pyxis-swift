import Foundation

public enum PyxisJSON {
	public static func decode(_ data: Data) throws -> PyxisMapDocument {
		var scanner = JSONKeyScanner(bytes: Array(data))
		try scanner.validate()

		let document = try JSONDecoder().decode(
			PyxisMapDocument.self,
			from: data
		)

		try PyxisValidation.validate(document)
		return document
	}

	public static func encode(_ document: PyxisMapDocument) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [
			.sortedKeys,
			.prettyPrinted,
			.withoutEscapingSlashes
		]
		return try encoder.encode(document)
	}
}
