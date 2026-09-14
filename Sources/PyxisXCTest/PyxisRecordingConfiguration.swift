import PyxisModel

/// Run metadata must identify the shared recording run, not an individual test's setup time.
public struct PyxisRecordingConfiguration: Sendable {
	public var project: PyxisProject
	public var run: PyxisRunMetadata
	public var domains: [PyxisDomain]
	public var profile: PyxisProfile
	public var journeyID: String?
	public var title: String?
	public var attempt: Int
	public var screenshotSource: PyxisScreenshotSource

	public init(
		project: PyxisProject,
		run: PyxisRunMetadata,
		domains: [PyxisDomain],
		profile: PyxisProfile,
		journeyID: String? = nil,
		title: String? = nil,
		attempt: Int = 0,
		screenshotSource: PyxisScreenshotSource = .application
	) {
		self.project = project
		self.run = run
		self.domains = domains
		self.profile = profile
		self.journeyID = journeyID
		self.title = title
		self.attempt = attempt
		self.screenshotSource = screenshotSource
	}
}
