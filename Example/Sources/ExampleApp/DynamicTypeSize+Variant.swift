import SwiftUI

internal extension DynamicTypeSize {
	var variantValue: String {
		switch self {
		case .xSmall: "x_small"
		case .small: "small"
		case .medium: "medium"
		case .large: "large"
		case .xLarge: "x_large"
		case .xxLarge: "xx_large"
		case .xxxLarge: "xxx_large"
		case .accessibility1: "accessibility_medium"
		case .accessibility2: "accessibility_large"
		case .accessibility3: "accessibility_x_large"
		case .accessibility4: "accessibility_xx_large"
		case .accessibility5: "accessibility_xxx_large"
		default: "unknown"
		}
	}
}
