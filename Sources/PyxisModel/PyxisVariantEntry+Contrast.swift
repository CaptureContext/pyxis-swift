extension PyxisVariantEntry.Accessibility {
	public enum Contrast: String, Codable, CaseIterable, Sendable {
		case normal, high
	}

	public static var contrastKey: String { "contrast" }

	@inlinable
	public static func contrast(_ value: Contrast) -> Self {
		.init(key: contrastKey, value: value.rawValue)
	}
}

extension PyxisVariantEntry {
	public static var accessibilityContrastKey: String {
		accessibilityKey + "." + Accessibility.contrastKey
	}
}
