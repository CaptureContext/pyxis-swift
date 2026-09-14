#if canImport(UIKit)
import UIKit
import PyxisModel

@MainActor
public func observedPyxisAccessibility() -> [String: PyxisVariantResult] {
	[
		"accessibility.reduce_motion": .init(
			status: .observed,
			value: String(UIAccessibility.isReduceMotionEnabled)
		),
		"accessibility.reduce_transparency": .init(
			status: .observed,
			value: String(UIAccessibility.isReduceTransparencyEnabled)
		),
		"accessibility.bold_text": .init(
			status: .observed,
			value: String(UIAccessibility.isBoldTextEnabled)
		),
		"os": .init(
			status: .observed,
			value: UIDevice.current.systemVersion
		),
	]
}
#endif
