#if canImport(UIKit) && canImport(XCTest)
public enum PyxisRecorderError: Error {
	case sourceNotCaptured(String)
	case readinessTimedOut(String)
	case conflictingState(String)
	case alreadyFinished
	case recordingInProgress
	case missingTestConfiguration
	case recordedXCTestFailure
}
#endif
