import SwiftUI

internal struct NotesView: View {
	private let subscription: ExampleSubscription

	@SwiftUI.State
	private var notes: [Note]

	internal init(subscription: ExampleSubscription) {
		self.subscription = subscription
		self._notes = .init(initialValue: [.weekend, .ideas])
	}

	internal var body: some View {
		NavigationStack {
			HomeView(notes: $notes, subscription: subscription)
		}
		.tint(.indigo)
	}
}
