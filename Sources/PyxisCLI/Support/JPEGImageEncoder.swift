import CoreGraphics
import Foundation
import ImageIO
import PyxisModel
import PyxisProcessing
import UniformTypeIdentifiers

internal struct JPEGImageEncoder {
	internal let quality: Double

	internal init(quality: Double) {
		self.quality = quality
	}

	internal func encode(_ content: PyxisAssetContent) throws -> PyxisAssetContent {
		guard
			let source = CGImageSourceCreateWithData(content.bytes as CFData, nil),
			let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
			let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
			let context = CGContext(
				data: nil,
				width: image.width,
				height: image.height,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: colorSpace,
				bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
			)
		else { throw CLIError.operation("Cannot decode image for JPEG conversion: \(content.asset.path)") }

		// JPEG has no alpha channel. Composite transparent images over white.
		let bounds: CGRect = .init(x: 0, y: 0, width: image.width, height: image.height)
		context.setFillColor(CGColor(gray: 1, alpha: 1))
		context.fill(bounds)
		context.draw(image, in: bounds)
		let bytes: NSMutableData = .init()
		guard
			let opaqueImage = context.makeImage(),
			let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)
		else { throw CLIError.operation("Cannot create JPEG: \(content.asset.path)") }

		CGImageDestinationAddImage(
			destination,
			opaqueImage,
			[kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
		)
		guard CGImageDestinationFinalize(destination)
		else { throw CLIError.operation("Cannot encode JPEG: \(content.asset.path)") }

		var asset: PyxisAsset = content.asset
		asset.path = "assets/converted.jpg"
		asset.mediaType = .jpeg
		asset.sha256 = nil
		return .init(asset: asset, bytes: bytes as Data)
	}
}
