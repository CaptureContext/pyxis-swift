import Foundation

internal struct StoreHead: Codable {
	internal let snapshotID: String

	internal init(snapshotID: String) {
		self.snapshotID = snapshotID
	}

	private enum CodingKeys: String, CodingKey {
		case snapshotID = "snapshot_id"
	}
}
