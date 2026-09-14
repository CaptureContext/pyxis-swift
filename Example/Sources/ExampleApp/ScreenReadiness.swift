import SwiftUI

/// An app-owned readiness marker lets tests verify the environment on every screen.
internal struct ScreenReadiness: ViewModifier {
	private let screen: String

	@Environment(\.colorScheme)
	private var colorScheme

	@Environment(\.layoutDirection)
	private var layoutDirection

	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	internal init(screen: String) {
		self.screen = screen
	}

	internal func body(content: Content) -> some View {
		#if DEBUG
		content
			.accessibilityIdentifier(screen + ".ready")
			.accessibilityValue([
				colorScheme.pyxisValue.rawValue,
				layoutDirection.pyxisValue.rawValue,
				dynamicTypeSize.variantValue,
			].joined(separator: "|"))
		#else
		content
		#endif
	}
}
