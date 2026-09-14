import ArgumentParser
import Foundation
import PyxisProcessing

internal struct StoreExportCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "export", abstract: "Export a store context or retained snapshot as a regular .pyx."
	)

	@OptionGroup
	internal var options: StoreOptions

	@Option(name: .long, help: "Retained snapshot ID. Omit to export the context's current snapshot.")
	internal var snapshot: String?

	@Option(name: .long, help: "New regular .pyx file to write.")
	internal var output: String

	internal init() {}

	internal func validate() throws {
		try requireNonempty(output, name: "--output")
		try options.validate()
	}

	internal func run() throws {
		let result: PyxisStoredRecording?
		if let snapshot {
			result = try options.store.snapshot(id: snapshot)
		} else {
			result = try options.store.snapshot(context: options.context)
		}
		guard let result else { throw CLIError.operation("No recording in context \(options.context)") }
		try PyxisArchive().write(result.bundle, to: URL(fileURLWithPath: output))
		print("Archive: \(output) (snapshot \(result.id))")
	}
}
