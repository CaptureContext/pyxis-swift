#if canImport(UIKit)
import UIKit
import PyxisModel

/// Overrides affect this window, not global device accessibility settings.
@MainActor
public func pyxisWindowAdapters(_ window: UIWindow) -> [String: PyxisAdapter] {
	[
		PyxisVariantEntry.colorSchemeKey: { [weak window] value in
			guard let window else {
				return .init(
					status: .unverified,
					reason: "Window was released."
				)
			}

			let style: UIUserInterfaceStyle
			switch PyxisVariantEntry.ColorScheme(rawValue: value) {
			case .light: style = .light
			case .dark: style = .dark
			case .system: style = .unspecified
			case nil:
				return .init(
					status: .unsupported,
					reason: "Unknown color scheme."
				)
			}

			window.overrideUserInterfaceStyle = style
			return .init(status: .applied, value: value)
		},

		PyxisVariantEntry.accessibilityContentSizeKey: { [weak window] value in
			guard let window else {
				return .init(
					status: .unverified,
					reason: "Window was released."
				)
			}

			guard let token = PyxisVariantEntry.Accessibility.ContentSize(rawValue: value) else {
				return .init(
					status: .unsupported,
					reason: "Unknown content size category."
				)
			}

			window.traitOverrides.preferredContentSizeCategory = switch token {
			case .xSmall: .extraSmall
			case .small: .small
			case .medium: .medium
			case .large: .large
			case .xLarge: .extraLarge
			case .xxLarge: .extraExtraLarge
			case .xxxLarge: .extraExtraExtraLarge
			case .accessibilityMedium: .accessibilityMedium
			case .accessibilityLarge: .accessibilityLarge
			case .accessibilityXLarge: .accessibilityExtraLarge
			case .accessibilityXXLarge: .accessibilityExtraExtraLarge
			case .accessibilityXXXLarge: .accessibilityExtraExtraExtraLarge
			}

			return .init(status: .applied, value: value)
		},

		PyxisVariantEntry.accessibilityContrastKey: { [weak window] value in
			guard let window else {
				return .init(
					status: .unverified,
					reason: "Window was released."
				)
			}

			guard let contrast = PyxisVariantEntry.Accessibility.Contrast(rawValue: value) else {
				return .init(
					status: .unsupported,
					reason: "Unknown contrast value."
				)
			}

			window.traitOverrides.accessibilityContrast = contrast == .high ? .high : .normal
			return .init(status: .applied, value: value)
		},
	]
}
#endif
