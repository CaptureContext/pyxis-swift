import Foundation
import Yams

internal struct RecordingConfiguration: Decodable {
	internal let version: Int
	internal let xcode: RecordingXcodeConfiguration
	internal let devices: [RecordingDeviceConfiguration]
	internal let variants: RecordingVariants
	internal let output: String
	internal let derivedData: String?
	internal let images: RecordingImageConfiguration?
	internal let coverage: RecordingCoverageConfiguration?
	internal let storage: RecordingStorageConfiguration?
	internal let archive: Bool?

	internal init(
		version: Int,
		xcode: RecordingXcodeConfiguration,
		devices: [RecordingDeviceConfiguration],
		output: String,
		variants: RecordingVariants = .matrix([:]),
		derivedData: String? = nil,
		images: RecordingImageConfiguration? = nil,
		coverage: RecordingCoverageConfiguration? = nil,
		storage: RecordingStorageConfiguration? = nil,
		archive: Bool? = nil
	) {
		self.version = version
		self.xcode = xcode
		self.devices = devices
		self.variants = variants
		self.output = output
		self.derivedData = derivedData
		self.images = images
		self.coverage = coverage
		self.storage = storage
		self.archive = archive
	}

	internal init(yaml: String) throws {
		self = try YAMLDecoder().decode(Self.self, from: yaml)
	}

	internal func validate() throws {
		guard version == 1 else { throw CLIError.operation("Unsupported recording configuration version: \(version)") }
		try requireNonempty(output, name: "output")
		if let derivedData { try requireNonempty(derivedData, name: "derived_data") }
		try xcode.validate()
		guard !devices.isEmpty else { throw CLIError.operation("Provide at least one recording device.") }
		for device in devices { try device.validate() }
		let identities: [String] = devices.map(\.name)
		guard Set(identities).count == identities.count
		else { throw CLIError.operation("Recording devices must be unique.") }
		try images?.publication.validate()
		try variants.validate(deviceNames: Set(identities))
		try coverage?.validate()
		try storage?.validate()
	}

	private enum CodingKeys: String, CodingKey {
		case version, xcode, devices, variants, output, images, coverage, storage, archive
		case derivedData = "derived_data"
	}
}
