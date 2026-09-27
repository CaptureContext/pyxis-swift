import Foundation

/// Portable ordinary pages. Temporary comparisons are intentionally not serialized.
public struct PyxisVisualizationDocument: Codable, Equatable, Sendable {
	public var format: String
	public var version: Int
	public var id: String
	public var title: String
	public var recordings: [PyxisArtifactReference]
	public var pages: [PyxisPage]

	@inlinable
	public init(
		id: String,
		title: String,
		recordings: [PyxisArtifactReference],
		pages: [PyxisPage],
		format: String = "pyxis.document",
		version: Int = 1
	) {
		self.format = format
		self.version = version
		self.id = id
		self.title = title
		self.recordings = recordings
		self.pages = pages
	}

	public init(data: Data) throws {
		var scanner = JSONKeyScanner(bytes: Array(data))
		try scanner.validate()
		self = try JSONDecoder().decode(Self.self, from: data)
		try validate()
	}

	public func validate() throws {
		guard format == "pyxis.document", version == 1, !id.isEmpty, !title.isEmpty
		else { throw PyxisValidationError("Unsupported visualization document") }
		try PyxisArtifactReference.validate(recordings)
		let available: Set<Data> = .init(recordings.map { Data($0.id.utf8) })
		var identities: Set<Data> = []
		for page in pages {
			guard !page.id.isEmpty, !page.title.isEmpty, identities.insert(Data(page.id.utf8)).inserted,
				Set(page.recordingIDs.map { Data($0.utf8) }).count == page.recordingIDs.count,
				page.recordingIDs.allSatisfy({ available.contains(Data($0.utf8)) })
			else { throw PyxisValidationError("Invalid page or missing recording reference") }
		}
	}
}

public struct PyxisPage: Codable, Equatable, Sendable {
	public var id: String
	public var title: String
	public var recordingIDs: [String]

	@inlinable
	public init(id: String, title: String, recordingIDs: [String]) {
		self.id = id
		self.title = title
		self.recordingIDs = recordingIDs
	}

	private enum CodingKeys: String, CodingKey {
		case id, title
		case recordingIDs = "recording_ids"
	}
}
