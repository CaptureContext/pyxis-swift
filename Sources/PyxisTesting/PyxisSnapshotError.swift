public enum PyxisSnapshotError: Error, Sendable {
	case outsideTest
	case recordingInProgress
	case timedOut
	case invalidImage
	case baseline(String)
}
