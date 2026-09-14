import Foundation

internal struct SimulatorDeviceType: Decodable {
	internal let name: String
	internal let identifier: String
	internal let modelIdentifier: String?

	internal init(name: String, identifier: String, modelIdentifier: String? = nil) {
		self.name = name
		self.identifier = identifier
		self.modelIdentifier = modelIdentifier
	}
}
