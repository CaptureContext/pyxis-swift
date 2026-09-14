import Foundation

internal struct RecordingSelection: Encodable {
	internal let order: Int
	internal let values: [String: String]

	internal init(order: Int, values: [String: String]) {
		self.order = order
		self.values = values
	}
}
