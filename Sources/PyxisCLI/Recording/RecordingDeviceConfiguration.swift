import Foundation

internal struct RecordingDeviceConfiguration: Decodable {
	internal let name: String
	internal let simulator: String?
	internal let runtime: String?
	internal let optional: Bool?

	internal init(name: String, simulator: String? = nil, runtime: String? = nil, optional: Bool? = nil) {
		self.name = name
		self.simulator = simulator
		self.runtime = runtime
		self.optional = optional
	}

	internal func validate() throws {
		try requireNonempty(name, name: "devices.name")
		if let simulator { try requireNonempty(simulator, name: "devices.simulator") }
		if let runtime { try requireNonempty(runtime, name: "devices.runtime") }
	}
}
