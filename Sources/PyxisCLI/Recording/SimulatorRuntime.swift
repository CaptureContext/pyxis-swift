import Foundation

internal struct SimulatorRuntime: Decodable {
	internal let identifier: String
	internal let version: String
	internal let platform: String
	internal let isAvailable: Bool
	internal let supportedDeviceTypes: [SimulatorDeviceType]

	internal init(
		identifier: String,
		version: String,
		platform: String,
		isAvailable: Bool,
		supportedDeviceTypes: [SimulatorDeviceType]
	) {
		self.identifier = identifier
		self.version = version
		self.platform = platform
		self.isAvailable = isAvailable
		self.supportedDeviceTypes = supportedDeviceTypes
	}
}
