import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

internal func drawDemoScreen(
	title: String,
	appearance: String,
	to url: URL
) throws {
	let dark: Bool = appearance == "dark"
	let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()

	guard let context = CGContext(
		data: nil,
		width: 390,
		height: 844,
		bitsPerComponent: 8,
		bytesPerRow: 0,
		space: colorSpace,
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
	) else {
		throw CocoaError(.coderInvalidValue)
	}

	context.setFillColor(CGColor(gray: dark ? 0.07 : 0.96, alpha: 1))
	context.fill(CGRect(x: 0, y: 0, width: 390, height: 844))
	context.setFillColor(CGColor(red: 0.4, green: 0.37, blue: 0.92, alpha: 1))
	context.fill(CGRect(x: 24, y: 530, width: 342, height: 150))

	let foreground: CGColor = .init(gray: dark ? 0.95 : 0.1, alpha: 1)
	drawText("9:41", x: 28, y: 795, size: 14, color: foreground, in: context)
	drawText(title, x: 24, y: 730, size: 34, color: foreground, in: context)
	drawText(
		"PYXIS EXAMPLE",
		x: 42,
		y: 637,
		size: 14,
		color: .init(gray: 1, alpha: 1),
		in: context
	)
	drawText(
		title == "Detail" ? "Your trial is active" : "Explore your app",
		x: 42,
		y: 594,
		size: 24,
		color: .init(gray: 1, alpha: 1),
		in: context
	)
	drawText(
		"Synthetic fixture • \(appearance)",
		x: 24,
		y: 487,
		size: 17,
		color: foreground,
		in: context
	)

	for (index, label) in ["Home", "Detail", "Settings"].enumerated() {
		drawText(
			label,
			x: 28,
			y: CGFloat(410 - index * 65),
			size: 20,
			color: foreground,
			in: context
		)
	}

	guard
		let image = context.makeImage(),
		let destination = CGImageDestinationCreateWithURL(
			url as CFURL,
			UTType.png.identifier as CFString,
			1,
			nil
		)
	else { throw CocoaError(.fileWriteUnknown) }

	CGImageDestinationAddImage(destination, image, nil)
	guard CGImageDestinationFinalize(destination)
	else { throw CocoaError(.fileWriteUnknown) }
}

private func drawText(
	_ string: String,
	x: CGFloat,
	y: CGFloat,
	size: CGFloat,
	color: CGColor,
	in context: CGContext
) {
	let font: CTFont = CTFontCreateWithName("Helvetica" as CFString, size, nil)
	let attributes: CFDictionary = [
		kCTFontAttributeName: font,
		kCTForegroundColorAttributeName: color,
	] as CFDictionary
	let attributed: CFAttributedString = CFAttributedStringCreate(
		nil,
		string as CFString,
		attributes
	)!
	context.textPosition = .init(x: x, y: y)
	CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
}
