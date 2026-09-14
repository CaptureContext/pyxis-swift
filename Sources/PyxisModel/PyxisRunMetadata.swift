import Foundation

public struct PyxisRunMetadata: Codable, Equatable, Sendable {
	public var id: String
	public var createdAt: Date
	public var provenance: [String: String]

	@inlinable
	public init(
		id: String,
		createdAt: Date,
		provenance: [String: String] = [:]
	) {
		self.id = id
		self.createdAt = createdAt
		self.provenance = provenance
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			id: container.decode(String.self, forKey: .id),
			createdAt: container.decode(ISO8601Timestamp.self, forKey: .createdAt).value,
			provenance: container.decode([String: String].self, forKey: .provenance)
		)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		try container.encode(ISO8601Timestamp(self.createdAt), forKey: .createdAt)
		try container.encode(self.provenance, forKey: .provenance)
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case createdAt = "created_at"
		case provenance
	}
}
