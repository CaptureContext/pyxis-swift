import SwiftUI

internal struct NoteDetailView: View {
	private let note: Note

	internal init(note: Note) {
		self.note = note
	}

	internal var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				Label(note.notebook, systemImage: note.symbol)
					.font(.subheadline)
					.foregroundStyle(.indigo)
				Text(note.title)
					.font(.largeTitle.bold())
					.modifier(ScreenReadiness(screen: "detail"))
				Text(note.body)
					.lineSpacing(6)
				Divider()
				Label("Saved for later", systemImage: "bookmark")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(24)
		}
		.navigationTitle("Note")
		.navigationBarTitleDisplayMode(.inline)
	}
}
