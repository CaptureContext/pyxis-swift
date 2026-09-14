import ArgumentParser

internal struct StoreCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "store", abstract: "Update and export a consumer-owned filesystem recording store.",
		subcommands: [StoreUpdateCommand.self, StoreExportCommand.self]
	)

	internal init() {}
}
