import Foundation

public struct PyxisObservation: Codable, Equatable, Sendable {
	public var id: String
	public var journeyID: String
	public var title: String
	public var testName: String
	public var profileID: String
	public var status: PyxisObservationStatus
	public var variants: [String: PyxisVariantResult]
	public var startedAt: Date?
	public var failure: String?
	public var runID: String?

	@inlinable
	public init(
		id: String,
		journeyID: String,
		title: String,
		testName: String,
		profileID: String,
		status: PyxisObservationStatus = .incomplete,
		variants: [String: PyxisVariantResult] = [:],
		startedAt: Date? = nil,
		failure: String? = nil,
		runID: String? = nil
	) {
		self.id = id
		self.journeyID = journeyID
		self.title = title
		self.testName = testName
		self.profileID = profileID
		self.status = status
		self.variants = variants
		self.startedAt = startedAt
		self.failure = failure
		self.runID = runID
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			id: container.decode(String.self, forKey: .id),
			journeyID: container.decode(String.self, forKey: .journeyID),
			title: container.decode(String.self, forKey: .title),
			testName: container.decode(String.self, forKey: .testName),
			profileID: container.decode(String.self, forKey: .profileID),
			status: container.decode(PyxisObservationStatus.self, forKey: .status),
			variants: container.decode([String: PyxisVariantResult].self, forKey: .variants),
			startedAt: container.contains(.startedAt) ? container.decode(ISO8601Timestamp.self, forKey: .startedAt).value : nil,
			failure: container.contains(.failure) ? container.decode(String.self, forKey: .failure) : nil,
			runID: container.contains(.runID) ? container.decode(String.self, forKey: .runID) : nil
		)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(self.id, forKey: .id)
		try container.encode(self.journeyID, forKey: .journeyID)
		try container.encode(self.title, forKey: .title)
		try container.encode(self.testName, forKey: .testName)
		try container.encode(self.profileID, forKey: .profileID)
		try container.encode(self.status, forKey: .status)
		try container.encode(self.variants, forKey: .variants)
		try container.encodeIfPresent(self.startedAt.map(ISO8601Timestamp.init), forKey: .startedAt)
		try container.encodeIfPresent(self.failure, forKey: .failure)
		try container.encodeIfPresent(self.runID, forKey: .runID)
	}

	private enum CodingKeys: String, CodingKey {
		case id
		case journeyID = "journey_id"
		case title
		case testName = "test_name"
		case profileID = "profile_id"
		case status
		case variants
		case startedAt = "started_at"
		case failure
		case runID = "run_id"
	}
}
