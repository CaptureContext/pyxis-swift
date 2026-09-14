import ArgumentParser

@main
internal struct PyxisCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "pyxis",
		abstract: "Record and inspect application journeys locally.",
		version: "0.1",
		subcommands: [
			ValidateCommand.self,
			PackCommand.self,
			StoreCommand.self,
			MergeCommand.self,
			OptimizeCommand.self,
			ExportCommand.self,
			CaptureCommand.self,
			RecordCommand.self,
			DemoCommand.self,
		]
	)

	internal init() {}

	@MainActor
	internal static func main() async {
		let task = Task { @MainActor in
			var command = try await asyncParseAsRoot()
			if var command = command as? any AsyncParsableCommand {
				try await command.run()
			} else {
				try command.run()
			}
			try Task.checkCancellation()
		}
		let signals: CommandSignals = .init { task.cancel() }
		do {
			try await task.value
			signals.stop()
		} catch {
			signals.stop()
			exit(withError: error is CancellationError ? ExitCode(130) : error)
		}
	}
}
