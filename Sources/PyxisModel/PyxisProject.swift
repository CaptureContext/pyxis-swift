import Foundation

public struct PyxisProject: Codable, Equatable, Sendable {
	public var id: String
	public var title: String

	@inlinable
	public init(
		id: String,
		title: String
	) {
		self.id = id
		self.title = title
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case title
	}
}
