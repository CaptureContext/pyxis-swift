extension PyxisRecordingEnvironment {
	public enum Key: String, CaseIterable, Sendable {
		case variants = "PYXIS_VARIANTS"
		case profileOrder = "PYXIS_PROFILE_ORDER"
		case runID = "PYXIS_RUN_ID"
		case runTimestamp = "PYXIS_RUN_TIMESTAMP"
		case deviceName = "PYXIS_DEVICE_NAME"
		case deviceModel = "PYXIS_DEVICE_MODEL"
	}
}
