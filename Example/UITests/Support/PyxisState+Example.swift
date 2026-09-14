import ExampleTesting

extension PyxisState {
	internal static let home: Self = .init(
		id: "home", screenID: "home", domainID: "notes", title: "Home", label: "Recent notes", order: 0
	)
	internal static let detail: Self = .init(
		id: "detail", screenID: "detail", domainID: "notes", title: "Note", label: "Weekend", order: 1
	)
	internal static let notebooks: Self = .init(
		id: "notebooks", screenID: "notebooks", domainID: "notes", title: "Notebooks", label: "Populated", order: 2
	)
	internal static let notebooksEmpty: Self = .init(
		id: "notebooks_empty", screenID: "notebooks", domainID: "notes", title: "Notebooks", label: "Empty", order: 3
	)
	internal static let editorEmpty: Self = .init(
		id: "editor_empty", screenID: "editor", domainID: "notes", title: "New note", label: "Empty", order: 4
	)
	internal static let editorKeyboard: Self = .init(
		id: "editor_keyboard", screenID: "editor", domainID: "notes", title: "New note", label: "Keyboard", order: 5
	)
	internal static let settings: Self = .init(
		id: "settings", screenID: "settings", domainID: "settings", title: "Settings", label: "Preferences", order: 0
	)
	internal static let subscription: Self = .init(
		id: "subscription", screenID: "subscription", domainID: "settings", title: "Notes Plus", label: "Trial", order: 1
	)
}
