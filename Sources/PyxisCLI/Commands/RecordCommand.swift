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

	@Option(name: .long, help: "Override the configured test selection. Repeat for several test identifiers.")
	internal var onlyTesting: [String] = []

	@Option(name: .long, help: "Select configured variations by key=value. Repeat to constrain more dimensions.")
	internal var variant: [String] = []

	@Flag(name: .long, help: "Explicitly update the configured shared store after the entire selection succeeds.")
	internal var updateStore: Bool = false

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
		if configuration.coverage != nil {
			printProgress("Warning: coverage.states is deprecated and ignored. Tests and native recording outcomes determine success.")
		}
		guard !updateStore || configuration.storage != nil
		else { throw CLIError.operation("--update-store requires storage in the configuration.") }
		for selector in onlyTesting { try requireNonempty(selector, name: "--only-testing") }
		let runner: RecordingRunner = .init(configuration: configuration, directory: file.deletingLastPathComponent())
		let plan: RecordingPlan = try await runner.resolvePlan().selecting(variant)
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		printProgress(String(decoding: try encoder.encode(plan), as: UTF8.self))
		guard !list else { return }
		try await runner.record(plan: plan, skipBuild: skipBuild, onlyTesting: onlyTesting, updateStore: updateStore)
	}
}
