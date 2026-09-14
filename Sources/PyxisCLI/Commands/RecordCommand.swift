import ArgumentParser
import Foundation

internal struct RecordCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "record",
		abstract: "Record configured iOS simulators and publish one archive.",
		discussion: "Paths in the YAML configuration are relative to its directory. Builds once, runs authored tests on isolated simulators, then exports and merges the recordings."
	)

	@Option(name: .long, help: "Recording YAML configuration. Defaults to pyxis.yaml.")
	internal var config: String = "pyxis.yaml"

	@Flag(name: .long, help: "Resolve devices and print the recording plan without building or recording.")
	internal var list: Bool = false

	@Flag(name: .long, help: "Reuse the configured derived_data directory. Omit after source or dependency changes.")
	internal var skipBuild: Bool = false

	internal init() {}

	internal func validate() throws {
		try requireNonempty(config, name: "--config")
	}

	internal func run() async throws {
		let file: URL = URL(fileURLWithPath: config).standardizedFileURL
		let configuration: RecordingConfiguration = try .init(
			yaml: String(contentsOf: file, encoding: .utf8)
		)
		try configuration.validate()
		let runner: RecordingRunner = .init(configuration: configuration, directory: file.deletingLastPathComponent())
		let plan: RecordingPlan = try await runner.resolvePlan()
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		printProgress(String(decoding: try encoder.encode(plan), as: UTF8.self))
		guard !list else { return }
		try await runner.record(plan: plan, skipBuild: skipBuild)
	}
}
