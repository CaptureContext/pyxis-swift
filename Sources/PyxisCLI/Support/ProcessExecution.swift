import Foundation
import Subprocess

@discardableResult
internal func runProcess(
	_ executable: String,
	_ arguments: [String],
	log: URL? = nil,
	environment: [String: String]? = nil,
	directory: URL? = nil
) async throws -> Int32 {
	try Task.checkCancellation()
	let configuration: Subprocess.Configuration = processConfiguration(
		executable, arguments, environment: environment, directory: directory
	)
	var handle: FileHandle?
	if let log {
		try Data().write(to: log, options: .withoutOverwriting)
		handle = try .init(forWritingTo: log)
	}
	defer { try? handle?.close() }

	let result = try await Subprocess.run(
		configuration,
		output: .fileDescriptor(.init(rawValue: handle?.fileDescriptor ?? STDOUT_FILENO), closeAfterSpawningProcess: false),
		error: .fileDescriptor(.init(rawValue: handle?.fileDescriptor ?? STDERR_FILENO), closeAfterSpawningProcess: false)
	)
	try Task.checkCancellation()
	return exitStatus(result.terminationStatus)
}

/// Stream bytes without the library's default collected-output size cap.
internal func processOutput(
	_ executable: String,
	_ arguments: [String],
	environment: [String: String]? = nil,
	directory: URL? = nil
) async throws -> String {
	try Task.checkCancellation()
	let result = try await Subprocess.run(
		processConfiguration(executable, arguments, environment: environment, directory: directory),
		input: .none,
		output: .sequence,
		error: .currentStandardError
	) { execution in
		var data: Data = .init()
		for try await chunk in execution.standardOutput {
			chunk.withUnsafeBytes { data.append(contentsOf: $0) }
		}
		return String(decoding: data, as: UTF8.self)
	}
	try Task.checkCancellation()
	guard result.terminationStatus.isSuccess else {
		throw CLIError.operation("\(executable) \(arguments.joined(separator: " ")) failed (\(exitStatus(result.terminationStatus))).")
	}
	return result.closureResult
}

private func processConfiguration(
	_ executable: String,
	_ arguments: [String],
	environment: [String: String]?,
	directory: URL?
) -> Subprocess.Configuration {
	var options: Subprocess.PlatformOptions = .init()
	// Only the spawned tool and its descendants receive cancellation signals.
	options.createSession = true
	options.teardownSequence = [
		.send(signal: .interrupt, toProcessGroup: true, allowedDurationToNextStep: .seconds(2)),
		.gracefulShutDown(toProcessGroup: true, allowedDurationToNextStep: .seconds(3)),
		.send(signal: .kill, toProcessGroup: true, allowedDurationToNextStep: .zero),
	]
	return .init(
		executable: .path(.init(executable)),
		arguments: .init(arguments),
		environment: environment.map { values in
			.custom(Dictionary(uniqueKeysWithValues: values.map { (.init(stringLiteral: $0.key), $0.value) }))
		} ?? .inherit,
		workingDirectory: directory.map { .init($0.path) },
		platformOptions: options
	)
}

private func exitStatus(_ status: Subprocess.TerminationStatus) -> Int32 {
	switch status {
	case let .exited(code): code
	case let .signaled(signal): 128 + signal
	}
}
