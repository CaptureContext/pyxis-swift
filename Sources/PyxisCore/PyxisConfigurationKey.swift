/// A typed configuration entry. Values may also be Sendable capability closures.
public protocol PyxisConfigurationKey: Sendable {
	associatedtype Value: Sendable
	static var defaultValue: Value { get }
}
