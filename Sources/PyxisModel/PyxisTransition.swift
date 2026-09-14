import Foundation

public struct PyxisTransition: Codable, Equatable, Sendable {
	public var id: String
	public var observationID: String
	public var fromStateID: String
	public var toStateID: String
	public var action: String
	public var kind: String
	public var sequence: Int
	public var status: PyxisTransitionStatus
	public var failure: String?

	@inlinable
	public init(
		id: String,
		observationID: String,
		fromStateID: String,
		toStateID: String,
		action: String,
		kind: String,
		sequence: Int,
		status: PyxisTransitionStatus,
		failure: String? = nil
	) {
		self.id = id
		self.observationID = observationID
		self.fromStateID = fromStateID
		self.toStateID = toStateID
		self.action = action
		self.kind = kind
		self.sequence = sequence
		self.status = status
		self.failure = failure
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			id: container.decode(String.self, forKey: .id),
			observationID: container.decode(String.self, forKey: .observationID),
			fromStateID: container.decode(String.self, forKey: .fromStateID),
			toStateID: container.decode(String.self, forKey: .toStateID),
			action: container.decode(String.self, forKey: .action),
			kind: container.decode(String.self, forKey: .kind),
			sequence: container.decode(Int.self, forKey: .sequence),
			status: container.decode(PyxisTransitionStatus.self, forKey: .status),
			failure: container.contains(.failure) ? container.decode(String.self, forKey: .failure) : nil
		)
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case observationID = "observation_id"
		case fromStateID = "from_state_id"
		case toStateID = "to_state_id"
		case action
		case kind
		case sequence
		case status
		case failure
	}
}
