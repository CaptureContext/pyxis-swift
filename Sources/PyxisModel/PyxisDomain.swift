import Foundation

public struct PyxisDomain: Codable, Equatable, Sendable {
	public var id: String
	public var title: String
	public var order: Int

	@inlinable
	public init(
		id: String,
		title: String,
		order: Int = 0
	) {
		self.id = id
		self.title = title
		self.order = order
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case title
		case order
	}
}
