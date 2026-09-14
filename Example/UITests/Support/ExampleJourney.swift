import ExampleTesting
internal enum ExampleJourney: String, Sendable {
	case writeNote = "write-note"
	case discoverPlus = "discover-plus"
	case dedicatedAsync = "dedicated-async"
	case existingAsyncTest = "existing-async-test"
	case tour, failure
	case assertionFailure = "assertion-failure"

	internal var title: String {
		switch self {
		case .writeNote: "Make room for a new idea"
		case .discoverPlus: "Personalize Notes"
		case .dedicatedAsync: "Dedicated async recording"
		case .tour: "Explore the app"
		case .existingAsyncTest, .failure, .assertionFailure: rawValue
		}
	}
}
