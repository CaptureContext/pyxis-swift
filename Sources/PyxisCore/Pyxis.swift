/// Reads the effective configuration on each access, without capturing an earlier scope.
@propertyWrapper
public struct Pyxis<Value: Sendable>: Sendable {
	private let read: @Sendable (PyxisConfiguration) -> Value

	public init<Key: PyxisConfigurationKey>(_ key: Key.Type) where Key.Value == Value {
		self.read = { $0[key] }
	}

	public init(_ keyPath: KeyPath<PyxisConfiguration, Value> & Sendable) {
		self.read = { $0[keyPath: keyPath] }
	}

	public var wrappedValue: Value { self.read(pyxisConfiguration) }
}
