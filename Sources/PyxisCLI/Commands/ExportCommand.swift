import ArgumentParser
import Foundation

internal struct ExportCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "export",
		abstract: "Export retained Pyxis attachments from an xcresult bundle."
	)

	@Option(
		name: .long,
		help: "Existing XCTest result bundle containing Pyxis attachments."
	)
	internal var xcresult: String

	@Option(
		name: .long,
		help: "Directory for the published bundle."
	)
	internal var output: String

	@OptionGroup
	internal var publication: PublicationOptions

	internal init() {}

	internal func validate() throws {
		try publication.validate()
		try requireNonempty(self.xcresult, name: "--xcresult")
		try requireNonempty(self.output, name: "--output")
	}

	internal func run() async throws {
		try publication.preflight()
		try await exportResult(
			URL(fileURLWithPath: self.xcresult),
			to: URL(fileURLWithPath: self.output),
			publication: publication
		)
	}
}
