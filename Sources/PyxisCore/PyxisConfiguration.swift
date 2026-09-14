import PyxisModel

/// A value snapshot of configuration. Copies do not share mutable dictionary storage.
public struct PyxisConfiguration: Sendable {
	private var values: [ObjectIdentifier: any Sendable]
	public package(set) var requested: PyxisVariants
	public package(set) var report: PyxisBootstrapReport?

	public init() {
		self.values = [:]
		self.requested = [:]
		self.report = nil
	}

	public subscript<Key: PyxisConfigurationKey>(_ key: Key.Type) -> Key.Value {
		get { self.values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue }
		set { self.values[ObjectIdentifier(key)] = newValue }
	}
}
