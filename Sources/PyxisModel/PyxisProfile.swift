import Foundation

public struct PyxisProfile: Codable, Equatable, Sendable {
	public var id: String
	public var title: String
	public var requested: PyxisVariants
	public var order: Int

	@inlinable
	public init(
		id: String,
		title: String,
		requested: PyxisVariants = [:],
		order: Int = 0
	) {
		self.id = id
		self.title = title
		self.requested = requested
		self.order = order
	}

	public init(from decoder: any Decoder) throws {
		let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
		try self.init(
			id: container.decode(String.self, forKey: .id),
			title: container.decode(String.self, forKey: .title),
			requested: container.decode(PyxisVariants.self, forKey: .requested),
			order: container.contains(.order) ? container.decode(Int.self, forKey: .order) : 0
		)
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case title
		case requested
		case order
	}
}
