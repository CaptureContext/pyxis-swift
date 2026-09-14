import ArgumentParser
import Foundation

internal struct CaptureCommand: AsyncParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "capture",
		abstract: "Run authored UI tests and export their captured map.",
		discussion: """
		Retains xcresult and logs on failure and attempts partial export. A failed
		test run exits nonzero even if a partial bundle was published. Existing
		result bundles and logs are never overwritten. This command does not
		create, shut down or delete simulators.
		"""
	)

	@Option(
		name: .long,
		help: "Xcode project path. Specify exactly one of --project or --workspace."
	)
	internal var project: String?

	@Option(
		name: .long,
		help: "Xcode workspace path. Specify exactly one of --project or --workspace."
	)
	internal var workspace: String?

	@Option(
		name: .long,
		help: "Xcode scheme containing the authored UI tests."
	)
	internal var scheme: String

	@Option(
		name: .long,
		help: "Explicit Xcode destination, such as 'platform=iOS Simulator,id=UUID'."
	)
	internal var destination: String

	@Option(
		name: .long,
		help: "Directory for the published bundle."
	)
	internal var output: String

	@Option(
		name: .long,
		help: "New xcresult path. Defaults to a unique sibling of the output directory."
	)
	internal var result: String?

	@Option(
		name: .long,
		help: "Run one XCTest selector, such as Target/TestClass/testMethod."
	)
	internal var onlyTesting: String?

	@Option(
		name: .long,
		help: "Isolated directory for Xcode build products."
	)
	internal var derivedData: String?

	@OptionGroup
	internal var publication: PublicationOptions

	internal init() {}

	internal func validate() throws {
		try publication.validate()
		guard (self.project != nil) != (self.workspace != nil) else {
			throw ArgumentParser.ValidationError("Specify exactly one of --project or --workspace.")
		}

		try requireNonempty(self.scheme, name: "--scheme")
		try requireNonempty(self.destination, name: "--destination")
		try requireNonempty(self.output, name: "--output")

		for (name, value) in [
			("--project", self.project),
			("--workspace", self.workspace),
			("--result", self.result),
			("--only-testing", self.onlyTesting),
			("--derived-data", self.derivedData),
		] {
			if let value { try requireNonempty(value, name: name) }
		}
	}

	internal func run() async throws {
		try publication.preflight()
		let containerArguments: [String]
		if let project = self.project {
			containerArguments = ["-project", project]

		} else if let workspace = self.workspace {
			containerArguments = ["-workspace", workspace]

		} else {
			throw ArgumentParser.ValidationError("Specify exactly one of --project or --workspace.")
		}

		let outputURL: URL = .init(fileURLWithPath: self.output)
		let resultURL: URL = self.result.map { URL(fileURLWithPath: $0) }
		?? outputURL.deletingLastPathComponent()
			.appendingPathComponent("pyxis-\(UUID().uuidString).xcresult")

		guard !FileManager.default.fileExists(atPath: resultURL.path)
		else { throw CLIError.operation("Result path already exists: \(resultURL.path)") }

		try FileManager.default.createDirectory(
			at: resultURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)

		var arguments: [String] = ["xcodebuild", "test"] + containerArguments + [
			"-scheme", self.scheme,
			"-destination", self.destination,
			"-resultBundlePath", resultURL.path,
			"-parallel-testing-enabled", "NO",
		]
		if let onlyTesting = self.onlyTesting {
			arguments.append("-only-testing:\(onlyTesting)")
		}
		if let derivedData = self.derivedData {
			arguments += ["-derivedDataPath", derivedData]
		}

		let logURL: URL = resultURL.appendingPathExtension("log")
		print("Running capture. Log: \(logURL.path)")

		let status: Int32 = try await runProcess("/usr/bin/xcrun", arguments, log: logURL)
		try await exportResult(resultURL, to: outputURL, publication: publication)

		guard status == 0 else {
			throw CLIError.operation(
				"xcodebuild failed (\(status)); partial bundle exported. Result: \(resultURL.path)"
			)
		}
	}
}
