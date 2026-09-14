import SwiftUI

internal struct SubscriptionView: View {
	private let subscription: ExampleSubscription

	internal init(subscription: ExampleSubscription) {
		self.subscription = subscription
	}

	internal var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				Image(systemName: "sparkles.rectangle.stack")
					.font(.system(size: 56))
					.foregroundStyle(.indigo)
				Text("More space to make it yours.")
					.font(.largeTitle.bold())
					.modifier(ScreenReadiness(screen: "subscription"))
				Text("Notes Plus")
					.font(.title3.weight(.semibold))
				Label("Unlimited notebooks", systemImage: "books.vertical")
				Label("Your favorite color themes", systemImage: "paintpalette")
				Label("Export a beautifully formatted copy", systemImage: "square.and.arrow.up")
				Divider()
				Text(subscription == .trial ? "Your trial is ready to explore." : "A little more room for your ideas.")
					.foregroundStyle(.secondary)
				Text("Preview only. No purchases are made in this example.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(24)
		}
		.navigationTitle("Notes Plus")
		.navigationBarTitleDisplayMode(.inline)
	}
}
