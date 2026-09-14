import ExampleTesting

internal struct ExampleProfile: Equatable, Sendable {
	internal typealias ColorScheme = PyxisVariantEntry.ColorScheme
	internal typealias LayoutDirection = PyxisVariantEntry.LayoutDirection
	internal typealias ContentSize = PyxisVariantEntry.Accessibility.ContentSize

	internal let colorScheme: ColorScheme
	internal let direction: LayoutDirection
	internal let contentSize: ContentSize

	internal init(
		colorScheme: ColorScheme = .dark,
		direction: LayoutDirection = .ltr,
		contentSize: ContentSize = .large
	) {
		self.colorScheme = colorScheme
		self.direction = direction
		self.contentSize = contentSize
	}
}
