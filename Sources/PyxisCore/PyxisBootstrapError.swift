public enum PyxisBootstrapError: Error, Equatable {
	case unsupportedVersion(Int)
	case alreadyPrepared
	case preparationInProgress
	case invalidReport(String)
}
