public struct PyxisStoredRecording: Sendable {
	public let id: String
	/// Original variation records. Each retains its own state declarations, profiles and provenance.
	public let recordings: [PyxisBundleInput]

	@inlinable
	public init(id: String, recordings: [PyxisBundleInput]) {
		self.id = id
		self.recordings = recordings
	}
}
