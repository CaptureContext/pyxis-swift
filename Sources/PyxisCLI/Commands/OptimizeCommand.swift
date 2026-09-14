import ArgumentParser
import Foundation

internal struct OptimizeCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "optimize",
		abstract: "Resize an existing recording locally and publish a separate copy.",
		discussion: "Accepts a recording folder, manifest, .pyx or ZIP. Defaults to 320px maximum image width. Requires ffmpeg; the original recording is never modified."
	)

	@Argument(help: "Recording folder, manifest JSON, .pyx or ZIP file.")
	internal var input: String

	@Option(name: .long, help: "Directory for the optimized recording.")
	internal var output: String

	@OptionGroup
	internal var publication: PublicationOptions

	internal init() {}

	internal mutating func validate() throws {
		try requireNonempty(input, name: "input")
		try requireNonempty(output, name: "--output")
		if publication.imageWidth == nil { publication.imageWidth = 320 }
		try publication.validate()
	}

	internal func run() async throws {
		let session: BundleInputSession = try .init(paths: [input])
		defer { withExtendedLifetime(session) {} }
		let document = try await publication.publish(
			inputs: session.inputs,
			to: URL(fileURLWithPath: output)
		)
		print("Optimized \(document.captures.count) captures to \(output)")
	}
}
