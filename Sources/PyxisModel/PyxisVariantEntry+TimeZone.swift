extension PyxisVariantEntry {
	public static var timeZoneKey: String { "time_zone" }

	@inlinable
	public static func timeZone(_ value: String) -> Self {
		.init(key: timeZoneKey, value: value)
	}
}
