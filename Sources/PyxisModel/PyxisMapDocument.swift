import Foundation

public struct PyxisMapDocument: Codable, Equatable, Sendable {
	public var format: PyxisDocumentFormat
	public var version: Int
	public var project: PyxisProject
	public var run: PyxisRunMetadata
	/// Original runs referenced by observations retained from previous store updates.
	public var recordingRuns: [PyxisRunMetadata]
	public var domains: [PyxisDomain]
	public var states: [PyxisState]
	public var profiles: [PyxisProfile]
	public var observations: [PyxisObservation]
	public var captures: [PyxisCapture]
	public var transitions: [PyxisTransition]

	@inlinable
	public init(
		format: PyxisDocumentFormat = .map,
		version: Int = 1,
		project: PyxisProject,
		run: PyxisRunMetadata,
		domains: [PyxisDomain] = [],
		states: [PyxisState] = [],
		profiles: [PyxisProfile] = [],
		observations: [PyxisObservation] = [],
		captures: [PyxisCapture] = [],
		transitions: [PyxisTransition] = [],
		recordingRuns: [PyxisRunMetadata] = []
	) {
		self.format = format
		self.version = version
		self.project = project
		self.run = run
		self.recordingRuns = recordingRuns
		self.domains = domains
		self.states = states
		self.profiles = profiles
		self.observations = observations
		self.captures = captures
		self.transitions = transitions
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		try self.init(
			format: container.decode(PyxisDocumentFormat.self, forKey: .format),
			version: container.decode(Int.self, forKey: .version),
			project: container.decode(PyxisProject.self, forKey: .project),
			run: container.decode(PyxisRunMetadata.self, forKey: .run),
			domains: container.decode([PyxisDomain].self, forKey: .domains),
			states: container.decode([PyxisState].self, forKey: .states),
			profiles: container.decode([PyxisProfile].self, forKey: .profiles),
			observations: container.decode([PyxisObservation].self, forKey: .observations),
			captures: container.decode([PyxisCapture].self, forKey: .captures),
			transitions: container.decode([PyxisTransition].self, forKey: .transitions),
			recordingRuns: container.contains(.recordingRuns)
			? container.decode([PyxisRunMetadata].self, forKey: .recordingRuns) : []
		)
	}

	/// The original run for an observation, including records retained by a selective update.
	public func recordingRun(for observation: PyxisObservation) -> PyxisRunMetadata? {
		guard let runID = observation.runID, Data(runID.utf8) != Data(run.id.utf8) else { return run }
		return recordingRuns.first { Data($0.id.utf8) == Data(runID.utf8) }
	}

	private enum CodingKeys: String, CodingKey {
		case format
		case version
		case project
		case run
		case recordingRuns = "recording_runs"
		case domains
		case states
		case profiles
		case observations
		case captures
		case transitions
	}
}
