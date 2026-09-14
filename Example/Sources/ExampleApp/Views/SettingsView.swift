import SwiftUI

internal struct SettingsView: View {
	private let subscription: ExampleSubscription

	@SwiftUI.State
	private var usesReminders: Bool

	@SwiftUI.State
	private var keepsOfflineCopy: Bool

	internal init(subscription: ExampleSubscription) {
		self.subscription = subscription
		self._usesReminders = .init(initialValue: false)
		self._keepsOfflineCopy = .init(initialValue: true)
	}

	internal var body: some View {
		Form {
			Section {
				Label("Make yourself at home.", systemImage: "person.crop.circle")
					.font(.title2.bold())
					.modifier(ScreenReadiness(screen: "settings"))
				NavigationLink {
					SubscriptionView(subscription: subscription)
				} label: {
					Label("Discover Notes Plus", systemImage: "sparkles")
						.foregroundStyle(.indigo)
				}
				.accessibilityIdentifier("open.subscription")
			}
			Section("Your routine") {
				Toggle("Writing reminders", isOn: $usesReminders)
				Toggle("Keep an offline copy", isOn: $keepsOfflineCopy)
			}
			Section {
				Label("Stored on this device", systemImage: "lock.shield")
				Text("A small, offline notebook. No account needed.")
					.foregroundStyle(.secondary)
			}
		}
		.navigationTitle("Settings")
	}
}
