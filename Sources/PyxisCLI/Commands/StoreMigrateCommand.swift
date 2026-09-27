import ArgumentParser
import Foundation
import PyxisProcessing

internal struct StoreMigrateCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(commandName: "migrate", abstract: "Migrate a legacy store to a separate destination, preserving history and the source.")

	@Argument
	internal var input: String

	@Option(name: .long)
	internal var output: String

	internal init() {}

	internal func run() throws {
		try PyxisRecordingStore.migrate(from: URL(fileURLWithPath: input), to: URL(fileURLWithPath: output))
		print("Migrated store: \(output). The original is unchanged.")
	}
}
