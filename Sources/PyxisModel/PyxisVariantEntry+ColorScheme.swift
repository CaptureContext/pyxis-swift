extension PyxisVariantEntry {
	public enum ColorScheme: String, Codable, CaseIterable, Sendable {
		case light, dark, system
	}

	public static var colorSchemeKey: String { "color_scheme" }

	@inlinable
	public static func colorScheme(_ value: ColorScheme) -> Self {
		.init(key: colorSchemeKey, value: value.rawValue)
	}
}
