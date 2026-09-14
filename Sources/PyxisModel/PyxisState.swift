import Foundation

public struct PyxisState: Codable, Equatable, Sendable {
	public var id: String
	public var screenID: String
	public var domainID: String
	public var title: String
	public var label: String
	public var order: Int
	public var metadata: [String: String]

	@inlinable
	public init(
		id: String,
		screenID: String,
		domainID: String,
		title: String,
		label: String = "",
		order: Int = 0,
		metadata: [String: String] = [:]
	) {
		self.id = id
		self.screenID = screenID
		self.domainID = domainID
		self.title = title
		self.label = label
		self.order = order
		self.metadata = metadata
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case screenID = "screen_id"
		case domainID = "domain_id"
		case title
		case label
		case order
		case metadata
	}
}
