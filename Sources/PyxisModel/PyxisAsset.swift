import Foundation

public struct PyxisAsset: Codable, Equatable, Sendable {
	public var path: String
	public var sha256: String?
	public var mediaType: PyxisMediaType
	public var width: Int
	public var height: Int

	@inlinable
	public init(
		path: String,
		sha256: String? = nil,
		mediaType: PyxisMediaType = .png,
		width: Int,
		height: Int
	) {
		self.path = path
		self.sha256 = sha256
		self.mediaType = mediaType
		self.width = width
		self.height = height
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		try self.init(
			path: container.decode(String.self, forKey: .path),
			sha256: container.contains(.sha256) ? container.decode(String.self, forKey: .sha256) : nil,
			mediaType: container.decode(PyxisMediaType.self, forKey: .mediaType),
			width: container.decode(Int.self, forKey: .width),
			height: container.decode(Int.self, forKey: .height)
		)
	}

	private enum CodingKeys: String, CodingKey {
		case path
		case sha256
		case mediaType = "media_type"
		case width
		case height
	}
}
