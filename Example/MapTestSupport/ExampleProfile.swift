import PyxisCore
import PyxisModel

internal struct ExampleProfile: Equatable, Sendable {
	internal typealias ColorScheme = PyxisVariantEntry.ColorScheme
	internal typealias LayoutDirection = PyxisVariantEntry.LayoutDirection
	internal typealias ContentSize = PyxisVariantEntry.Accessibility.ContentSize

	internal enum Orientation: String, CaseIterable, Sendable {
		case portrait
		case landscape
	}

	internal let orientation: Orientation
	internal let colorScheme: ColorScheme
	internal let direction: LayoutDirection
	internal let contentSize: ContentSize

	internal init(
		colorScheme: ColorScheme = .dark,
		direction: LayoutDirection = .ltr,
		contentSize: ContentSize = .large,
		orientation: Orientation = .portrait
	) {
		self.orientation = orientation
		self.colorScheme = colorScheme
		self.direction = direction
		self.contentSize = contentSize
	}
}
