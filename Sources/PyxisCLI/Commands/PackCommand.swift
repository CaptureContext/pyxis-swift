import ArgumentParser
import Foundation
import PyxisProcessing

internal struct PackCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "pack", abstract: "Create a self-contained regular .pyx from an existing recording."
	)

	@Argument(help: "Recording directory, manifest, .pyx or ZIP.")
	internal var input: String

	@Option(name: .long, help: "New .pyx file to write.")
	internal var output: String

	internal init() {}

	internal func validate() throws {
		try requireNonempty(input, name: "input")
		try requireNonempty(output, name: "--output")
	}

	internal func run() throws {
		let session: BundleInputSession = try .init(paths: [input])
		defer { withExtendedLifetime(session) {} }
		try PyxisArchive().write(session.inputs[0], to: URL(fileURLWithPath: output))
		print("Archive: \(output)")
	}
}
