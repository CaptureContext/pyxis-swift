extension PyxisVariantEntry {
	/// Keys are relative to the accessibility namespace until composed into an entry.
	public struct Accessibility: Equatable, Hashable, Sendable {
		public let key: String
		public let value: String

		@inlinable
		public init(key: String, value: String) {
			self.key = key
			self.value = value
		}
	}

	public static var accessibilityKey: String { "accessibility" }

	@inlinable
	public static func accessibility(_ value: Accessibility) -> Self {
		.init(key: accessibilityKey + "." + value.key, value: value.value)
	}
}
