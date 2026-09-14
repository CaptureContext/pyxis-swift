import SwiftUI

internal struct HomeView: View {
	private let subscription: ExampleSubscription

	@Binding
	private var notes: [Note]

	internal init(notes: Binding<[Note]>, subscription: ExampleSubscription) {
		self.subscription = subscription
		self._notes = notes
	}

	internal var body: some View {
		List {
			Section {
				VStack(alignment: .leading, spacing: 12) {
					Image(systemName: "sparkles")
						.font(.largeTitle)
						.foregroundStyle(.indigo)
					Text("Room for a thought.")
						.font(.title2.bold())
						.modifier(ScreenReadiness(screen: "home"))
					Text("Save the small things you want to come back to.")
						.foregroundStyle(.secondary)
				}
				.padding(.vertical, 12)
			}
			Section("Recent notes") {
				ForEach(notes) { note in
					NavigationLink {
						NoteDetailView(note: note)
					} label: {
						Label {
							VStack(alignment: .leading, spacing: 4) {
								Text(note.title)
								Text(note.notebook)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						} icon: {
							Image(systemName: note.symbol).foregroundStyle(.indigo)
						}
					}
					.accessibilityIdentifier(note.id == Note.weekend.id ? "open.detail" : "note.\(note.id)")
				}
			}
			Section {
				NavigationLink {
					NotebooksView(notes: $notes)
				} label: {
					Label("Notebooks", systemImage: "books.vertical")
				}
				.accessibilityIdentifier("open.notebooks")
				NavigationLink {
					SettingsView(subscription: subscription)
				} label: {
					Label("Settings", systemImage: "slider.horizontal.3")
				}
				.accessibilityIdentifier("open.settings")
			}
		}
		.navigationTitle("Notes")
	}
}
