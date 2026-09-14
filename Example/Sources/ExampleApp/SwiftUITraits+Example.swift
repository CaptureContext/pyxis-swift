import SwiftUI
import PyxisModel

internal extension ColorScheme {
	var pyxisValue: PyxisVariantEntry.ColorScheme { self == .dark ? .dark : .light }
}

internal extension LayoutDirection {
	var pyxisValue: PyxisVariantEntry.LayoutDirection { self == .rightToLeft ? .rtl : .ltr }
}
