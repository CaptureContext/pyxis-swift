import PyxisModel

/// Shared run, declarations and requested conditions for either recording adapter.
public struct PyxisSessionConfiguration: Sendable {
	public var project: PyxisProject
	public var run: PyxisRunMetadata
	public var domains: [PyxisDomain]
	public var profile: PyxisProfile

	public init(project: PyxisProject, run: PyxisRunMetadata, domains: [PyxisDomain], profile: PyxisProfile) {
		self.project = project
		self.run = run
		self.domains = domains
		self.profile = profile
	}
}
