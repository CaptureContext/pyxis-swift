extension PyxisVariantEntry {
	public enum LayoutDirection: String, Codable, CaseIterable, Sendable {
		case ltr, rtl
	}

	public static var layoutDirectionKey: String { "layout_direction" }

	@inlinable
	public static func layoutDirection(_ value: LayoutDirection) -> Self {
		.init(key: layoutDirectionKey, value: value.rawValue)
	}
}
