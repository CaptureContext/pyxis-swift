import SwiftUI

internal struct NotebooksView: View {
	@Environment(\.layoutDirection)
	private var layoutDirection

	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	@Binding
	private var notes: [Note]

	@SwiftUI.State
	private var isEditorPresented: Bool

	internal init(notes: Binding<[Note]>) {
		self._notes = notes
		self._isEditorPresented = .init(initialValue: false)
	}

	internal var body: some View {
		List {
			Section {
				Text("A place for every idea.")
					.font(.title2.bold())
					.modifier(ScreenReadiness(screen: "notebooks"))
				Text("Keep everyday moments and future plans together.")
					.foregroundStyle(.secondary)
			}
			if notes.isEmpty {
				ContentUnavailableView("No notes yet", systemImage: "book.closed", description: Text("Your next idea starts with a new note."))
					.accessibilityIdentifier("notebooks.empty")
			}
			ForEach(["Everyday", "Ideas"].filter { notebook in notes.contains { $0.notebook == notebook } }, id: \.self) { notebook in
				Section(notebook) {
					ForEach(notes.filter { $0.notebook == notebook }) { note in
						NavigationLink(note.title) {
							NoteDetailView(note: note)
						}
					}
				}
			}
			if !notes.isEmpty {
				Section {
					Button("Clear notebook", role: .destructive) { notes.removeAll() }
						.accessibilityIdentifier("notebooks.clear")
				}
			}
		}
		.navigationTitle("Notebooks")
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("New note", systemImage: "square.and.pencil") {
					isEditorPresented = true
				}
				.accessibilityIdentifier("open.editor")
			}
		}
		.sheet(isPresented: $isEditorPresented) {
			NoteEditorView { notes.append($0) }
				.environment(\.layoutDirection, layoutDirection)
				.environment(\.dynamicTypeSize, dynamicTypeSize)
		}
	}
}
