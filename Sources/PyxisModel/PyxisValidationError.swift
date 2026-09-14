import Foundation

public struct PyxisValidationError: Error, CustomStringConvertible, Sendable {
	public let description: String

	@inlinable
	public init(_ description: String) {
		self.description = description
	}
}
