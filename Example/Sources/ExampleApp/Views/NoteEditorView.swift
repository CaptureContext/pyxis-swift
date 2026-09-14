import SwiftUI

internal struct NoteEditorView: View {
	private let save: (Note) -> Void

	@Environment(\.dismiss)
	private var dismiss

	@SwiftUI.State
	private var title: String

	@SwiftUI.State
	private var text: String

	internal init(save: @escaping (Note) -> Void) {
		self.save = save
		self._title = .init(initialValue: "")
		self._text = .init(initialValue: "")
	}

	internal var body: some View {
		NavigationStack {
			Form {
				Section {
					Text("Start with one thought.")
						.font(.title2.bold())
						.modifier(ScreenReadiness(screen: "editor"))
					TextField("Title", text: $title)
						.accessibilityIdentifier("editor.title")
					TextField("What is on your mind?", text: $text, axis: .vertical)
						.lineLimit(4...8)
						.accessibilityIdentifier("editor.body")
				} footer: {
					Label("Saves to Everyday", systemImage: "book.closed")
				}
			}
			.navigationTitle("New note")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
						.accessibilityIdentifier("editor.cancel")
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save", action: saveButtonTapped)
						.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
						.accessibilityIdentifier("editor.save")
				}
			}
		}
	}

	private func saveButtonTapped() {
		save(.init(
			id: UUID().uuidString,
			title: title,
			notebook: "Everyday",
			body: text,
			symbol: "note.text"
		))
		dismiss()
	}
}
