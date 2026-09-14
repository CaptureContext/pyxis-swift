import Foundation

/// All subprocesses use literal arguments. Configuration paths are relative to the config file.
internal struct RecordingTools: Sendable {
	internal var execute: @Sendable ([String], URL?, [String: String]) async throws -> Int32
	internal var output: @Sendable ([String]) async throws -> String

	internal init(
		execute: @escaping @Sendable ([String], URL?, [String: String]) async throws -> Int32,
		output: @escaping @Sendable ([String]) async throws -> String
	) {
		self.execute = execute
		self.output = output
	}

	internal init(directory: URL) {
		var values: [String: String] = ProcessInfo.processInfo.environment
		// SwiftPM sets the host SDK for command plugins. Xcode selects the destination's SDK.
		values.removeValue(forKey: "SDKROOT")
		let inheritedEnvironment: [String: String] = values
		self.init(
			execute: { arguments, log, overrides in
				try await runProcess(
					"/usr/bin/xcrun", arguments, log: log,
					environment: inheritedEnvironment.merging(overrides) { _, new in new },
					directory: directory
				)
			},
			output: { arguments in
				try await processOutput("/usr/bin/xcrun", arguments, environment: inheritedEnvironment, directory: directory)
			}
		)
	}

	internal func requireSuccess(
		_ arguments: [String],
		log: URL? = nil,
		environment: [String: String] = [:]
	) async throws {
		let status: Int32 = try await execute(arguments, log, environment)
		guard status == 0
		else { throw CLIError.operation("xcrun \(arguments.first ?? "") failed (\(status)).\(log.map { " Log: \($0.path)" } ?? "")") }
	}
}
