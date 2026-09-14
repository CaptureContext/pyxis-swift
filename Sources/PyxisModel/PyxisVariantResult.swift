import Foundation

public struct PyxisVariantResult: Codable, Equatable, Sendable {
	public var status: PyxisVariantStatus
	public var value: String?
	public var reason: String?

	@inlinable
	public init(
		status: PyxisVariantStatus,
		value: String? = nil,
		reason: String? = nil
	) {
		self.status = status
		self.value = value
		self.reason = reason
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			status: container.decode(PyxisVariantStatus.self, forKey: .status),
			value: container.contains(.value) ? container.decode(String.self, forKey: .value) : nil,
			reason: container.contains(.reason) ? container.decode(String.self, forKey: .reason) : nil
		)
	}

	private enum CodingKeys: String, CodingKey {
		case status
		case value
		case reason
	}
}
