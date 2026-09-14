import Foundation

internal struct RecordingSimulator: Sendable {
	internal let destination: RecordingDestination
	internal let tools: RecordingTools

	internal init(destination: RecordingDestination, tools: RecordingTools) {
		self.destination = destination
		self.tools = tools
	}

	nonisolated(nonsending)
	internal func withDevice<Value>(
		name: String,
		logDirectory: URL,
		operation: (String) async throws -> Value
	) async throws -> Value {
		try Task.checkCancellation()
		// Retain the returned identifier even if cancellation arrives during creation.
		let creation = Task.detached { [tools, destination] in
			try await tools.output(["simctl", "create", name, destination.deviceType, destination.runtime])
		}
		let identifier: String = try await creation.value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard UUID(uuidString: identifier) != nil
		else { throw CLIError.operation("simctl returned an invalid device identifier: \(identifier)") }

		let result: Result<Value, any Error>
		do {
			try Task.checkCancellation()
			try await tools.requireSuccess(["simctl", "boot", identifier], log: logDirectory.appendingPathComponent("boot.log"))
			try await tools.requireSuccess(["simctl", "bootstatus", identifier, "-b"], log: logDirectory.appendingPathComponent("boot-status.log"))
			result = .success(try await operation(identifier))
		} catch { result = .failure(error) }

		let cleanup = await Task.detached { [tools] in
			do {
				// Shutdown may fail if boot failed. Deletion remains authoritative.
				_ = try? await tools.execute(["simctl", "shutdown", identifier], logDirectory.appendingPathComponent("shutdown.log"), [:])
				try await tools.requireSuccess(["simctl", "delete", identifier], log: logDirectory.appendingPathComponent("delete.log"))
				return Result<Void, any Error>.success(())
			} catch { return Result<Void, any Error>.failure(error) }
		}.value

		switch (result, cleanup) {
		case let (.success(value), .success):
			try Task.checkCancellation()
			return value
		case let (.failure(error), .success): throw error
		case let (.success, .failure(error)):
			throw CLIError.operation("Could not delete Pyxis simulator \(identifier): \(error)")
		case let (.failure(error), .failure(cleanupError)):
			throw CLIError.operation("\(error)\nCould not delete Pyxis simulator \(identifier): \(cleanupError)")
		}
	}
}
