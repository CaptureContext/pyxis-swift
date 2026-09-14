import Foundation

internal struct RecordingPlan: Encodable {
	internal let devices: [RecordingDestination]
	internal let skipped: [String]
	internal let selections: [RecordingSelection]

	internal init(devices: [RecordingDestination], skipped: [String], selections: [RecordingSelection]) {
		self.devices = devices
		self.skipped = skipped
		self.selections = selections
	}

	internal init(
		requests: [RecordingDeviceConfiguration],
		deviceTypes: [SimulatorDeviceType],
		runtimes: [SimulatorRuntime],
		variants: RecordingVariants = .matrix([:])
	) throws {
		try variants.validate(deviceNames: Set(requests.map(\.name)))
		let requestedCombinations: [[String: String]] = variants.combinations(deviceNames: requests.map(\.name))
		var devices: [RecordingDestination] = []
		var skipped: [String] = []
		for request in requests {
			guard requestedCombinations.contains(where: { $0["device"] == request.name }) else { continue }
			let simulator: String = request.simulator ?? request.name
			let type: SimulatorDeviceType? = deviceTypes.first {
				$0.name == simulator || $0.identifier == simulator
			}
			let runtime: SimulatorRuntime? = runtimes.filter {
				$0.isAvailable && $0.platform == "iOS"
				&& (request.runtime == nil || request.runtime == $0.identifier || request.runtime == $0.version)
				&& $0.supportedDeviceTypes.contains { $0.identifier == type?.identifier }
			}.max { $0.version.compare($1.version, options: .numeric) == .orderedAscending }
			guard let type, let model = type.modelIdentifier, let runtime else {
				let reason: String = "\(request.name): no installed device type and compatible iOS runtime\(request.runtime.map { " (\($0))" } ?? "")"
				guard request.optional == true else { throw CLIError.operation(reason) }
				skipped.append(reason)
				continue
			}
			let destination: RecordingDestination = .init(
				name: request.name, deviceType: type.identifier, model: model,
				runtime: runtime.identifier, osVersion: runtime.version
			)
			guard !devices.contains(where: { $0.deviceType == destination.deviceType && $0.runtime == destination.runtime })
			else { throw CLIError.operation("Duplicate resolved destination: \(type.name) \(runtime.version)") }
			devices.append(destination)
		}
		guard !devices.isEmpty else { throw CLIError.operation("No requested recording devices are available.") }
		let selections: [RecordingSelection] = variants.combinations(deviceNames: devices.map(\.name))
			.enumerated().map { .init(order: $0.offset, values: $0.element) }
		self.init(devices: devices, skipped: skipped, selections: selections)
	}
}
