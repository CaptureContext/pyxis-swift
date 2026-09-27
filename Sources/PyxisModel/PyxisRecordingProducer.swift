/// Provenance of an observation; it does not change the meaning of a UI state or profile.
public struct PyxisRecordingProducer: Codable, Equatable, Sendable {
	public var framework: String
	public var captureMethod: String

	public init(framework: String, captureMethod: String) {
		self.framework = framework
		self.captureMethod = captureMethod
	}

	private enum CodingKeys: String, CodingKey {
		case framework
		case captureMethod = "capture_method"
	}
}
