extension PyxisVariantEntry {
	public static var deviceKey: String { "device" }

	@inlinable
	public static func device(_ value: String) -> Self {
		.init(key: deviceKey, value: value)
	}
}
