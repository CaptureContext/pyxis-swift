extension PyxisVariantEntry.Accessibility {
	public enum ContentSize: String, Codable, CaseIterable, Sendable {
		case xSmall = "x_small"
		case small, medium, large
		case xLarge = "x_large"
		case xxLarge = "xx_large"
		case xxxLarge = "xxx_large"
		case accessibilityMedium = "accessibility_medium"
		case accessibilityLarge = "accessibility_large"
		case accessibilityXLarge = "accessibility_x_large"
		case accessibilityXXLarge = "accessibility_xx_large"
		case accessibilityXXXLarge = "accessibility_xxx_large"
	}

	public static var contentSizeKey: String { "content_size" }

	@inlinable
	public static func contentSize(_ value: ContentSize) -> Self {
		.init(key: contentSizeKey, value: value.rawValue)
	}
}

extension PyxisVariantEntry {
	public static var accessibilityContentSizeKey: String {
		accessibilityKey + "." + Accessibility.contentSizeKey
	}
}
