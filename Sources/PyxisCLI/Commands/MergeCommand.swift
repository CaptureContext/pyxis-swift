import ArgumentParser
import Foundation
import PyxisProcessing

internal struct MergeCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "merge",
		abstract: "Merge compatible observations and publish a bundle atomically."
	)

	@Option(
		name: .long,
		help: "Directory for the published bundle."
	)
	internal var output: String

	@Argument(help: "One or more fragment or map directories, manifest JSON files, .pyx or ZIP files.")
	internal var inputs: [String]

	@OptionGroup
	internal var publication: PublicationOptions

	internal init() {}

	internal func validate() throws {
		try publication.validate()
		try requireNonempty(self.output, name: "--output")

		guard !self.inputs.isEmpty else {
			throw ArgumentParser.ValidationError("Provide at least one input bundle or manifest.")
		}

		for path in self.inputs {
			try requireNonempty(path, name: "input")
		}
	}

	internal func run() async throws {
		try publication.preflight()
		let session: BundleInputSession = try .init(paths: self.inputs)
		defer { withExtendedLifetime(session) {} }
		let destination: URL = .init(fileURLWithPath: self.output)
		let document = try await publication.publish(
			inputs: session.inputs,
			to: destination
		)
		print("Published \(document.captures.count) captures to \(destination.path)")
	}
}
