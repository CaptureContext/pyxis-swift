import Foundation

internal struct RecordingXcodeConfiguration: Decodable {
	internal let project: String?
	internal let workspace: String?
	internal let scheme: String
	internal let testRun: String?
	internal let onlyTesting: [String]
	internal let buildArguments: [String]?
	internal let testArguments: [String]?
	internal let environment: [String: String]?

	internal init(
		project: String? = nil,
		workspace: String? = nil,
		scheme: String,
		onlyTesting: [String],
		buildArguments: [String]? = nil,
		testArguments: [String]? = nil,
		environment: [String: String]? = nil,
		testRun: String? = nil
	) {
		self.project = project
		self.workspace = workspace
		self.scheme = scheme
		self.testRun = testRun
		self.onlyTesting = onlyTesting
		self.buildArguments = buildArguments
		self.testArguments = testArguments
		self.environment = environment
	}

	internal func validate() throws {
		guard (project != nil) != (workspace != nil)
		else { throw CLIError.operation("Specify exactly one xcode.project or xcode.workspace.") }
		try requireNonempty(scheme, name: "xcode.scheme")
		if let testRun { try requireNonempty(testRun, name: "xcode.test_run") }
		if let project { try requireNonempty(project, name: "xcode.project") }
		if let workspace { try requireNonempty(workspace, name: "xcode.workspace") }
		guard !onlyTesting.isEmpty
		else { throw CLIError.operation("Select authored recording tests in xcode.only_testing.") }
		for selector in onlyTesting { try requireNonempty(selector, name: "xcode.only_testing") }
		for key in (environment ?? [:]).keys {
			guard !key.isEmpty, !key.contains("="), !key.hasPrefix("PYXIS_")
			else { throw CLIError.operation("Invalid or reserved test environment key: \(key)") }
		}

		// These arguments own the recording lifecycle and cannot be redirected by extra arguments.
		let reserved: Set<String> = [
			"-project", "-workspace", "-scheme", "-destination", "-resultBundlePath",
			"-derivedDataPath", "-xctestrun", "-parallel-testing-enabled", "-sdk",
			"-only-testing", "-skip-testing", "-test-iterations", "-retry-tests-on-failure",
			"-run-tests-until-failure", "-testPlan", "-only-test-configuration", "-skip-test-configuration",
			"build", "test", "build-for-testing", "test-without-building", "clean", "archive",
		]
		for argument in (buildArguments ?? []) + (testArguments ?? []) {
			let key: String = String(argument.prefix { $0 != ":" && $0 != "=" })
			guard !reserved.contains(key)
			else { throw CLIError.operation("Pyxis manages the Xcode argument \(key); use the recording configuration fields.") }
		}
	}

	private enum CodingKeys: String, CodingKey {
		case project, workspace, scheme, environment
		case testRun = "test_run"
		case onlyTesting = "only_testing"
		case buildArguments = "build_arguments"
		case testArguments = "test_arguments"
	}
}
