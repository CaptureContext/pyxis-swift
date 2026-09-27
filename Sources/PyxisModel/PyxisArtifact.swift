import Foundation

/// Describes the container independently of the recording manifest.
public struct PyxisArtifact: Codable, Equatable, Sendable {
	public var format: String
	public var version: Int
	public var type: PyxisArtifactType
	public var id: String?
	public var recordings: [PyxisArtifactReference]

	@inlinable
	public init(
		format: String = "pyxis.artifact",
		version: Int = 2,
		type: PyxisArtifactType = .regular,
		id: String? = nil,
		recordings: [PyxisArtifactReference] = []
	) {
		self.format = format
		self.version = version
		self.type = type
		self.id = id
		self.recordings = recordings
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		try self.init(
			format: container.decode(String.self, forKey: .format),
			version: container.decode(Int.self, forKey: .version),
			type: container.decode(PyxisArtifactType.self, forKey: .type),
			id: container.contains(.id) ? container.decode(String.self, forKey: .id) : nil,
			recordings: container.contains(.recordings)
			? container.decode([PyxisArtifactReference].self, forKey: .recordings) : []
		)
	}

	public init(data: Data, allowLegacy: Bool = false) throws {
		var scanner: JSONKeyScanner = .init(bytes: Array(data))
		try scanner.validate()
		self = try JSONDecoder().decode(Self.self, from: data)
		try validate(allowLegacy: allowLegacy)
	}

	public func validate(allowLegacy: Bool = false) throws {
		guard format == "pyxis.artifact", version == 2 || (allowLegacy && version == 1)
		else { throw PyxisValidationError("Unsupported artifact format or version") }
		if version == 1 {
			guard type == .regular, id == nil, recordings.isEmpty
			else { throw PyxisValidationError("Invalid legacy artifact") }
			return
		}
		guard let id, !id.isEmpty
		else { throw PyxisValidationError("A recording artifact requires an identity") }
		guard (type == .regular && recordings.isEmpty) || (type == .composition && !recordings.isEmpty)
		else { throw PyxisValidationError("Only compositions contain child recordings") }
		try PyxisArtifactReference.validate(recordings)
	}

	public func encoded() throws -> Data {
		try validate()
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(self)
	}

	private enum CodingKeys: String, CodingKey {
		case format, version, type, id, recordings
	}
}
