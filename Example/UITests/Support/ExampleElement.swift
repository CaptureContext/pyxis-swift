import ExampleTesting
internal enum ExampleElement: Sendable {
	case ready(ExampleScreen)
	case note(String)
	case report, openDetail, openNotebooks, openSettings, openSubscription, openEditor
	case notebooksEmpty, clearNotebook, editorTitle, editorBody, cancelNote, saveNote
	case missing

	internal var identifier: String {
		switch self {
		case let .ready(screen): screen.rawValue + ".ready"
		case let .note(id): "note.\(id)"
		case .report: "pyxis.bootstrap.report"
		case .openDetail: "open.detail"
		case .openNotebooks: "open.notebooks"
		case .openSettings: "open.settings"
		case .openSubscription: "open.subscription"
		case .openEditor: "open.editor"
		case .notebooksEmpty: "notebooks.empty"
		case .clearNotebook: "notebooks.clear"
		case .editorTitle: "editor.title"
		case .editorBody: "editor.body"
		case .cancelNote: "editor.cancel"
		case .saveNote: "editor.save"
		case .missing: "missing"
		}
	}
}
