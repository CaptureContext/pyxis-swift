import ArgumentParser
import Foundation
import PyxisModel
import PyxisProcessing

internal struct ComposeCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "compose", abstract: "Nest recordings in .pyx or create a portable .pyxis page."
	)

	@Argument(help: "New-format .pyx archives to embed without flattening.")
	internal var inputs: [String]

	@Option(name: .long, help: "New .pyx or .pyxis destination.")
	internal var output: String

	@Option(name: .long, help: "Document and page title.")
	internal var title: String = "Recordings"

	internal init() {}

	internal func run() throws {
		guard !inputs.isEmpty else { throw CLIError.operation("Provide recording archives to compose.") }
		let archive = PyxisArchive()
		let sources = inputs.map { URL(fileURLWithPath: $0) }
		let destination = URL(fileURLWithPath: output)
		// Validate complete contents before creating a composition with usable children.
		let session = try BundleInputSession(paths: inputs)
		defer { withExtendedLifetime(session) {} }
		if destination.pathExtension.lowercased() == "pyxis" {
			let references = try archive.references(for: sources)
			let document = PyxisVisualizationDocument(
				id: UUID().uuidString.lowercased(), title: title, recordings: references,
				pages: [.init(id: UUID().uuidString.lowercased(), title: title, recordingIDs: Array(Set(references.map(\.id))).sorted())]
			)
			try archive.writeDocument(document, sources: sources, to: destination)
		} else {
			guard destination.pathExtension.lowercased() == "pyx" else { throw CLIError.operation("Use .pyx or .pyxis for the output.") }
			try archive.compose(sources, to: destination)
		}
		print("Composed: \(output)")
	}
}

internal struct MigrateCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "migrate", abstract: "Explicitly convert a legacy .pyx to the new container, preserving the source."
	)

	@Argument
	internal var input: String

	@Option(name: .long)
	internal var output: String

	internal init() {}

	internal func run() throws {
		try PyxisArchive().migrate(from: URL(fileURLWithPath: input), to: URL(fileURLWithPath: output))
		print("Migrated: \(output). The original is unchanged.")
	}
}
