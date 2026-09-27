/// Optional regression assertion. Capturing for a map alone never creates a baseline.
public struct PyxisSnapshotBaseline: Sendable {
	public var directory: String
	public var name: String
	public var record: Bool

	public init(directory: String, name: String, record: Bool = false) {
		self.directory = directory
		self.name = name
		self.record = record
	}
}
