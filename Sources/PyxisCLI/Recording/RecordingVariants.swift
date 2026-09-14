import Foundation

/// Object syntax expands a matrix; array syntax records only the listed configurations.
internal enum RecordingVariants: Decodable {
	case matrix([String: [String]])
	case configurations([[String: String]])

	internal init(from decoder: any Decoder) throws {
		let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
		if let configurations = try? container.decode([[String: String]].self) {
			self = .configurations(configurations)
		} else {
			self = try .matrix(container.decode([String: [String]].self))
		}
	}

	internal func validate(deviceNames: Set<String>) throws {
		switch self {
		case let .matrix(dimensions):
			for (key, values) in dimensions {
				guard !values.isEmpty, Set(values).count == values.count
				else { throw CLIError.operation("Variant \(key) needs nonempty, unique values.") }
				for value in values { try validate(key: key, value: value, deviceNames: deviceNames) }
			}
		case let .configurations(configurations):
			guard !configurations.isEmpty
			else { throw CLIError.operation("Provide at least one variant configuration.") }
			for configuration in configurations {
				for (key, value) in configuration { try validate(key: key, value: value, deviceNames: deviceNames) }
			}
		}
		let expanded: [[String: String]] = combinations(deviceNames: deviceNames.sorted())
		guard Set(expanded).count == expanded.count
		else { throw CLIError.operation("Variant configurations overlap. Each combination must be recorded once.") }
	}

	internal func combinations(deviceNames: [String]) -> [[String: String]] {
		let configurations: [[String: String]]
		switch self {
		case let .matrix(dimensions):
			configurations = dimensions.keys.sorted().reduce([[:]]) { combinations, key in
				combinations.flatMap { combination in
					(dimensions[key] ?? []).map { value in
						combination.merging([key: value]) { _, new in new }
					}
				}
			}
		case let .configurations(values):
			configurations = values
		}
		return configurations.flatMap { configuration in
			let devices: [String] = configuration["device"].map { [$0] } ?? deviceNames
			return devices.filter { deviceNames.contains($0) }.map { device in
				configuration.merging(["device": device]) { _, new in new }
			}
		}
	}

	private func validate(key: String, value: String, deviceNames: Set<String>) throws {
		try requireNonempty(key, name: "variants key")
		try requireNonempty(value, name: "variants.\(key)")
		guard key != "device" || deviceNames.contains(value)
		else { throw CLIError.operation("Unknown variant device: \(value). Add it to devices first.") }
	}
}
