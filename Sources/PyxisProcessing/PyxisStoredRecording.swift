public struct PyxisStoredRecording: Sendable {
	public let id: String
	public let bundle: PyxisBundleInput

	@inlinable
	public init(id: String, bundle: PyxisBundleInput) {
		self.id = id
		self.bundle = bundle
	}
}
