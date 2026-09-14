/// One requested variant. Custom keys and values retain their exact spelling.
public struct PyxisVariantEntry: Equatable, Hashable, Sendable {
	public let key: String
	public let value: String

	@inlinable
	public init(key: String, value: String) {
		self.key = key
		self.value = value
	}
}
