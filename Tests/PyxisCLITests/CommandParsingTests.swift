import ArgumentParser
import Testing
@testable import pyxis

@Suite
struct CommandParsingTests {
	@Test
	func captureRequiresExactlyOneContainerBeforeExecution() async throws {
		let required = ["--scheme", "Demo", "--destination", "platform=iOS Simulator,id=EXAMPLE", "--output", "map"]
		#expect(throws: (any Error).self) { try CaptureCommand.parse(required) }
		#expect(throws: (any Error).self) {
			try CaptureCommand.parse(required + ["--project", "Demo.xcodeproj", "--workspace", "Demo.xcworkspace"])
		}
		let parsed = try CaptureCommand.parse(required + ["--workspace", "A workspace.xcworkspace"])
		#expect(parsed.workspace == "A workspace.xcworkspace")
		#expect(parsed.project == nil)
	}

	@Test
	func capturePreservesLiteralPathsAndExistingFlagNames() async throws {
		let command = try CaptureCommand.parse([
			"--project", "Project with spaces.xcodeproj", "--scheme", "Example",
			"--destination", "platform=iOS Simulator,id=EXAMPLE", "--output", "Maps/$(literal)",
			"--only-testing", "Tests/Journey/testTour", "--derived-data", "Build data", "--result", "Run.xcresult",
		])
		#expect(command.output == "Maps/$(literal)")
		#expect(command.onlyTesting == "Tests/Journey/testTour")
		#expect(command.derivedData == "Build data")
		#expect(command.result == "Run.xcresult")
	}

	@Test
	func requiredAndEmptyArgumentsAreRejected() async throws {
		let invalidCommands = [
			["validate"], ["validate", ""], ["demo"], ["demo", "--output", ""],
			["merge", "--output", "map"], ["merge", "--output", "map", ""],
			["export", "--xcresult", "run.xcresult"], ["export", "--xcresult", "", "--output", "map"],
			["capture", "--project", "", "--scheme", "Demo", "--destination", "device", "--output", "map"],
			["capture", "--project", "Demo.xcodeproj", "--scheme", "", "--destination", "device", "--output", "map"],
			["capture", "--project", "Demo.xcodeproj", "--scheme", "Demo", "--destination", "device", "--output", "map", "--result", ""],
			["demo", "--unknown"],
			["pack", "input.pyx"],
			["store", "update", "input.pyx"],
			["store", "update", "input.pyx", "--storage", ""],
			["store", "update", "input.pyx", "--storage", "store", "--context", "../elsewhere"],
			["store", "update", "input.pyx", "--storage", "store", "--policy", "unknown"],
			["store", "export", "--storage", "store"],
		]
		for arguments in invalidCommands {
			#expect(throws: (any Error).self) { try PyxisCommand.parseAsRoot(arguments) }
		}
	}

	@Test
	func everySubcommandProvidesHelpWithoutRequiredArguments() async throws {
		for name in ["validate", "merge", "export", "capture", "demo", "optimize", "record", "pack", "store"] {
			var command = try PyxisCommand.parseAsRoot([name, "--help"])
			let isHelp = type(of: command).configuration.commandName == "help"
			#expect(isHelp)
			guard isHelp else { continue }
			do {
				try command.run()
				Issue.record("Expected the help command to return a help request.")
			} catch {
				#expect(PyxisCommand.exitCode(for: error) == .success)
				#expect(PyxisCommand.fullMessage(for: error).contains("USAGE: pyxis \(name)"))
			}
		}
	}

	@Test
	func storesAcceptExternalPathsAndExplicitContexts() async throws {
		let command = try StoreUpdateCommand.parse([
			"recording.pyx", "--storage", "/Volumes/Shared recordings/$(literal)",
			"--context", "feature-camera", "--policy", "update",
		])
		#expect(command.options.storage == "/Volumes/Shared recordings/$(literal)")
		#expect(command.options.context == "feature-camera")
		#expect(command.policy == "update")
		let export = try StoreExportCommand.parse(["--storage", "store", "--snapshot", "snapshot-id", "--output", "complete.pyx"])
		#expect(export.snapshot == "snapshot-id")
		#expect(export.options.context == "default")
	}

	@Test
	func mergeAcceptsMultipleInputsAndEndOfOptions() async throws {
		let command = try MergeCommand.parse(["--output", "map", "first", "second", "--", "--literal-path"])
		#expect(command.inputs == ["first", "second", "--literal-path"])
	}
}
