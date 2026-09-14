import Foundation

internal struct Note: Identifiable, Hashable {
	internal let id: String
	internal let title: String
	internal let notebook: String
	internal let body: String
	internal let symbol: String

	internal init(
		id: String,
		title: String,
		notebook: String,
		body: String,
		symbol: String
	) {
		self.id = id
		self.title = title
		self.notebook = notebook
		self.body = body
		self.symbol = symbol
	}

	internal static let weekend: Note = .init(
		id: "weekend",
		title: "A slower weekend",
		notebook: "Everyday",
		body: "Take the long way to the bakery. Find a quiet corner, order something warm, and leave the afternoon open.\n\nBring a book and a notebook. A good day does not need a full itinerary.",
		symbol: "sun.horizon"
	)

	internal static let ideas: Note = .init(
		id: "ideas",
		title: "Things worth making",
		notebook: "Ideas",
		body: "A reading lamp. A small herb garden. More room for the things we already love.",
		symbol: "lightbulb"
	)
}
