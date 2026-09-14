extension PyxisVariantEntry {
	public static var localeKey: String { "locale" }

	@inlinable
	public static func locale(_ value: String) -> Self {
		.init(key: localeKey, value: value)
	}
}
