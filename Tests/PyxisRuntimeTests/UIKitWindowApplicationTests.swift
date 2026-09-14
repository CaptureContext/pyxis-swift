#if canImport(UIKit)
import UIKit
import Testing
import PyxisCore
import PyxisRuntime

@Suite
@MainActor
struct UIKitWindowApplicationTests {
	@Test
	func builtInsApplyToMultipleWindowsAndCanBeRepeated() async throws {
		let configuration = preparedConfiguration()
		let first = UIWindow()
		let second = UIWindow()
		let firstReport = try applyPyxis(to: first, configuration: configuration)
		let secondReport = try applyPyxis(to: second, configuration: configuration)
		let repeated = try applyPyxis(to: first, configuration: configuration)

		for window in [first, second] {
			#expect(window.overrideUserInterfaceStyle == .dark)
			#expect(window.traitOverrides.preferredContentSizeCategory == .accessibilityLarge)
			#expect(window.traitOverrides.accessibilityContrast == .high)
		}
		#expect(firstReport == secondReport)
		#expect(repeated == firstReport)
		#expect(firstReport?.variants["color_scheme"]?.status == .applied)
		#expect(firstReport?.variants["accessibility.content_size"]?.status == .applied)
		#expect(firstReport?.variants["accessibility.contrast"]?.status == .applied)
		#expect(firstReport?.variants["subscription.status"]?.value == "trial")
		#expect(configuration.report?.variants["color_scheme"]?.status == .unverified)
	}

	@Test
	func customWindowAdapterOverridesBuiltInWithoutAffectingOtherWindows() async throws {
		let configuration = preparedConfiguration()
		let customWindow = UIWindow()
		let ordinaryWindow = UIWindow()
		let custom = try applyPyxis(to: customWindow, configuration: configuration, adapters: [
			"color_scheme": { _ in
				customWindow.overrideUserInterfaceStyle = .light
				return .init(status: .applied, value: "light")
			},
		])
		let ordinary = try withPyxis(configuration) { try applyPyxis(to: ordinaryWindow) }
		#expect(customWindow.overrideUserInterfaceStyle == .light)
		#expect(ordinaryWindow.overrideUserInterfaceStyle == .dark)
		#expect(customWindow.traitOverrides.accessibilityContrast == .high)
		#expect(custom?.variants["color_scheme"]?.value == "light")
		#expect(ordinary?.variants["color_scheme"]?.value == "dark")
		#expect(configuration.report?.variants["color_scheme"]?.status == .unverified)
	}

	@Test
	func absentPreparationDoesNothingAndWindowIsNotRetained() async throws {
		let window = UIWindow()
		window.overrideUserInterfaceStyle = .light
		var invoked = false
		let absent = try applyPyxis(to: window, configuration: .init(), adapters: [
			"color_scheme": { value in
				invoked = true
				return .init(status: .applied, value: value)
			},
		])
		#expect(absent == nil)
		#expect(!invoked)
		#expect(window.overrideUserInterfaceStyle == .light)

		weak var releasedWindow: UIWindow?
		try autoreleasepool {
			let temporary = UIWindow()
			releasedWindow = temporary
			try applyPyxis(to: temporary, configuration: preparedConfiguration())
		}
		#expect(releasedWindow == nil)
	}

	private func preparedConfiguration() -> PyxisConfiguration {
		var configuration = PyxisConfiguration()
		configuration.requested = [
			"color_scheme": "dark",
			"accessibility.content_size": "accessibility_large",
			"accessibility.contrast": "high",
			"subscription.status": "trial",
		]
		configuration.report = .init(variants: [
			"subscription.status": .init(status: .applied, value: "trial"),
		]).covering(configuration.requested)
		return configuration
	}
}
#endif
