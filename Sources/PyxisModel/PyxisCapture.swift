import Foundation

public struct PyxisCapture: Codable, Equatable, Sendable {
	public var id: String
	public var stateID: String
	public var observationID: String
	public var sequence: Int
	public var asset: PyxisAsset

	@inlinable
	public init(
		id: String,
		stateID: String,
		observationID: String,
		sequence: Int,
		asset: PyxisAsset
	) {
		self.id = id
		self.stateID = stateID
		self.observationID = observationID
		self.sequence = sequence
		self.asset = asset
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case stateID = "state_id"
		case observationID = "observation_id"
		case sequence
		case asset
	}
}
