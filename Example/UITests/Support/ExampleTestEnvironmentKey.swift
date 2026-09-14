/// Controls for this example's verification tests, not the Pyxis recording protocol.
internal enum ExampleTestEnvironmentKey: String, Sendable {
	case asyncProbe = "EXAMPLE_ASYNC_PROBE"
	case verifyAsyncFailure = "EXAMPLE_VERIFY_ASYNC_FAILURE"
	case verifyAssertionFailure = "EXAMPLE_VERIFY_ASSERTION_FAILURE"
}

internal extension Dictionary where Key == String, Value == String {
	subscript(_ key: ExampleTestEnvironmentKey) -> String? {
		get { self[key.rawValue] }
		set { self[key.rawValue] = newValue }
	}
}
