import UIKit
import PyxisModel
import PyxisRuntime

@MainActor
open class ExampleApplicationDelegate: UIResponder, UIApplicationDelegate {
	internal private(set) var subscription: ExampleSubscription = .none
	internal private(set) var report: PyxisBootstrapReport = .init(variants: [:])

	public func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		#if DEBUG
		do {
			report = try preparePyxis(adapters: [
				"subscription.status": { [unowned self] value in
					guard let subscription = ExampleSubscription(rawValue: value)
					else { return .init(status: .unsupported, reason: "Unknown subscription fixture.") }
					self.subscription = subscription
					return .init(status: .applied, value: value)
				},
				PyxisVariantEntry.deviceKey: { _ in
					guard let name = observedDeviceName()
					else { return .init(status: .unverified, reason: "The simulator model could not be verified.") }
					return .init(status: .observed, value: name)
				},
			]) ?? report
		} catch {
			report.variants["bootstrap"] = .init(status: .unverified, reason: String(describing: error))
		}
		#endif
		return true
	}
}
