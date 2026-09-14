import Foundation

internal struct RecordingImageConfiguration: Decodable {
	internal let width: Int?
	internal let jpegQuality: Double?
	internal let ffmpeg: String?

	internal init(width: Int? = nil, jpegQuality: Double? = nil, ffmpeg: String? = nil) {
		self.width = width
		self.jpegQuality = jpegQuality
		self.ffmpeg = ffmpeg
	}

	internal var publication: PublicationOptions {
		.init(imageWidth: width, jpegQuality: jpegQuality, ffmpeg: ffmpeg)
	}

	private enum CodingKeys: String, CodingKey {
		case width, ffmpeg
		case jpegQuality = "jpeg_quality"
	}
}
