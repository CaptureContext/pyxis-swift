import Foundation

/// Describes the container independently of the recording manifest.
public struct PyxisArtifact: Codable, Equatable, Sendable {
	public var format: String
	public var version: Int
	public var type: PyxisArtifactType

	@inlinable
	public init(
		format: String = "pyxis.artifact",
		version: Int = 1,
		type: PyxisArtifactType = .regular
	) {
		self.format = format
		self.version = version
		self.type = type
	}

	public init(data: Data) throws {
		var scanner: JSONKeyScanner = .init(bytes: Array(data))
		try scanner.validate()
		self = try JSONDecoder().decode(Self.self, from: data)
		try validate()
	}

	public func validate() throws {
		guard format == "pyxis.artifact", version == 1
		else { throw PyxisValidationError("Unsupported artifact format or version") }
	}

	public func encoded() throws -> Data {
		try validate()
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		return try encoder.encode(self)
	}
}
