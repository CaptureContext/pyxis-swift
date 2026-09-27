import Foundation

/// A physically embedded, independently extractable recording archive.
public struct PyxisArtifactReference: Codable, Equatable, Sendable {
	public var id: String
	public var path: String
	public var sha256: String

	@inlinable
	public init(id: String, path: String, sha256: String) {
		self.id = id
		self.path = path
		self.sha256 = sha256
	}

	public static func validate(_ references: [Self]) throws {
		var paths: Set<String> = []
		var identities: [Data: String] = [:]
		for reference in references {
			try PyxisValidation.validatePath(reference.path)
			guard !reference.id.isEmpty, reference.path.hasSuffix(".pyx"),
				reference.sha256.count == 64,
				reference.sha256.allSatisfy({ "0123456789abcdef".contains($0) }),
				paths.insert(reference.path).inserted
			else { throw PyxisValidationError("Invalid embedded recording reference") }
			if let previous = identities[Data(reference.id.utf8)], previous != reference.sha256 {
				throw PyxisValidationError("Conflicting contents for recording identity: \(reference.id)")
			}
			identities[Data(reference.id.utf8)] = reference.sha256
		}
	}
}
