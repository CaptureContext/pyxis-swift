public enum PyxisRecordingError: Error, Sendable {
	case alreadyFinished
	case sourceNotCaptured(String)
	case conflictingState(String)
	case unknownTransition
	case invalidImage
}
