import SwiftUI
import UIKit
import PyxisModel
import PyxisRuntime

@MainActor
open class ExampleSceneDelegate: UIResponder, UIWindowSceneDelegate {
	public var window: UIWindow?

	public func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard
			let scene = scene as? UIWindowScene,
			let appDelegate = UIApplication.shared.delegate as? ExampleApplicationDelegate
		else { return }

		let window: UIWindow = .init(windowScene: scene)
		let direction: LayoutDirection = {
			#if DEBUG
			if let requested = pyxisConfiguration.requested[PyxisVariantEntry.layoutDirectionKey].flatMap(PyxisVariantEntry.LayoutDirection.init(rawValue:)) {
				return requested == .rtl ? .rightToLeft : .leftToRight
			}
			#endif
			return UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
		}()

		#if DEBUG
		var report: PyxisBootstrapReport = appDelegate.report
		do {
			report = try applyPyxis(to: window, adapters: [
				PyxisVariantEntry.layoutDirectionKey: { [unowned window] value in
					guard let direction = PyxisVariantEntry.LayoutDirection(rawValue: value)
					else { return .init(status: .unsupported, reason: "Expected ltr or rtl.") }
					window.semanticContentAttribute = direction == .rtl ? .forceRightToLeft : .forceLeftToRight
					return .init(status: .applied, value: value)
				},
			]) ?? report
		} catch {
			report.variants["bootstrap"] = .init(status: .unverified, reason: String(describing: error))
		}
		#endif

		let content = NotesView(subscription: appDelegate.subscription)
			.environment(\.layoutDirection, direction)
		#if DEBUG
		let root = content.overlay(alignment: .bottomTrailing) {
			BootstrapReportView(report: report).environment(\.layoutDirection, direction)
		}
		#else
		let root = content
		#endif
		window.rootViewController = UIHostingController(rootView: root)
		self.window = window
		window.makeKeyAndVisible()
	}
}
