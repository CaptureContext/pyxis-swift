import Foundation

internal struct RecordingDestination: Codable, Sendable {
	internal let name: String
	internal let deviceType: String
	internal let model: String
	internal let runtime: String
	internal let osVersion: String

	internal init(name: String, deviceType: String, model: String, runtime: String, osVersion: String) {
		self.name = name
		self.deviceType = deviceType
		self.model = model
		self.runtime = runtime
		self.osVersion = osVersion
	}

	private enum CodingKeys: String, CodingKey {
		case name, model, runtime
		case deviceType = "device_type"
		case osVersion = "os_version"
	}
}
