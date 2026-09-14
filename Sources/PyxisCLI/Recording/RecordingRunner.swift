import Foundation
import PyxisCore
import PyxisModel
import PyxisProcessing

internal struct RecordingRunner {
	internal let configuration: RecordingConfiguration
	internal let directory: URL
	internal let tools: RecordingTools

	internal init(configuration: RecordingConfiguration, directory: URL) {
		self.configuration = configuration
		self.directory = directory
		self.tools = .init(directory: directory)
	}

	internal func resolvePlan() async throws -> RecordingPlan {
		let decoder: JSONDecoder = .init()
		let types: [String: [SimulatorDeviceType]] = try await decoder.decode(
			[String: [SimulatorDeviceType]].self,
			from: Data(tools.output(["simctl", "list", "devicetypes", "--json"]).utf8)
		)
		let runtimes: [String: [SimulatorRuntime]] = try await decoder.decode(
			[String: [SimulatorRuntime]].self,
			from: Data(tools.output(["simctl", "list", "runtimes", "--json"]).utf8)
		)
		return try .init(requests: configuration.devices, deviceTypes: types["devicetypes"] ?? [], runtimes: runtimes["runtimes"] ?? [], variants: configuration.variants)
	}

	internal func record(plan: RecordingPlan, skipBuild: Bool) async throws {
		var publication: PublicationOptions = configuration.images?.publication ?? .init(imageWidth: nil)
		if let ffmpeg = publication.ffmpeg { publication.ffmpeg = resolve(ffmpeg).path }
		try publication.preflight()
		guard !skipBuild || configuration.derivedData != nil
		else { throw CLIError.operation("--skip-build requires derived_data in the configuration.") }

		let now: Date = .init()
		let runID: String = UUID().uuidString.lowercased()
		let output: URL = resolve(configuration.output).appendingPathComponent(runID)
		let derivedData: URL = configuration.derivedData.map(resolve)
		?? output.appendingPathComponent("DerivedData")
		try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
		try writeJSON(plan, to: output.appendingPathComponent("plan.json"))
		printProgress("Recording run: \(output.path)")

		let xcode: RecordingXcodeConfiguration = configuration.xcode
		var container: [String] = ["-scheme", xcode.scheme, "-derivedDataPath", derivedData.path]
		if let project = xcode.project { container += ["-project", resolve(project).path] }
		if let workspace = xcode.workspace { container += ["-workspace", resolve(workspace).path] }
		let buildStartedAt: Date? = skipBuild ? nil : Date()
		if !skipBuild {
			printProgress("Building tests. Log: \(output.appendingPathComponent("build.log").path)")
			try await tools.requireSuccess(
				["xcodebuild", "build-for-testing"] + container
				+ ["-destination", "generic/platform=iOS Simulator"] + (xcode.buildArguments ?? []),
				log: output.appendingPathComponent("build.log")
			)
		}

		let source: URL = try xcode.testRun.map(resolve) ?? RecordingTestRun.locate(
			in: derivedData.appendingPathComponent("Build/Products"), scheme: xcode.scheme, modifiedAfter: buildStartedAt
		)
		let testRun: RecordingTestRun = try .init(data: Data(contentsOf: source), testRoot: source.deletingLastPathComponent())

		var bundles: [PyxisBundleInput] = []
		var failures: [String] = []
		for (index, destination) in plan.devices.enumerated() {
			let folder: URL = output.appendingPathComponent("device-\(index + 1)")
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
			printProgress("Recording \(destination.name), iOS \(destination.osVersion). Log: \(folder.appendingPathComponent("tests.log").path)")
			do {
				try await RecordingSimulator(destination: destination, tools: tools).withDevice(
					name: "Pyxis-\(runID)-\(index + 1)",
					logDirectory: folder
				) { identifier in
					let recording: PyxisRecordingEnvironment = .init(
						runID: runID,
						runCreatedAt: now,
						deviceName: destination.name,
						deviceModel: destination.model
					)
					let values: [String: String] = try (xcode.environment ?? [:])
						.merging(recording.encoded()) { _, new in new }
					let selections: [RecordingSelection] = plan.selections.filter { $0.values["device"] == destination.name }
					let testFile: URL = folder.appendingPathComponent("Recording.xctestrun")
					try testRun.data(selections: selections, environment: values).write(to: testFile, options: .withoutOverwriting)
					let result: URL = folder.appendingPathComponent("Tests.xcresult")
					let status: Int32 = try await tools.execute(
						["xcodebuild", "test-without-building", "-xctestrun", testFile.path,
							"-destination", "platform=iOS Simulator,id=\(identifier)",
							"-parallel-testing-enabled", "NO", "-resultBundlePath", result.path,
						] + xcode.onlyTesting.map { "-only-testing:\($0)" } + (xcode.testArguments ?? []),
						folder.appendingPathComponent("tests.log"), [:]
					)
					if status != 0 { failures.append("\(destination.name): xcodebuild exited \(status).") }
					// A failed XCTest run may still contain useful captures.
					let bundle: URL = folder.appendingPathComponent("bundle")
					try await exportResult(result, to: bundle, publication: publication)
					try bundles.append(loadBundleInput(bundle.path))
				}

			} catch is CancellationError {
				throw CancellationError()
			} catch {
				try Task.checkCancellation()
				failures.append("\(destination.name): \(error)")
			}
		}

		try writeJSON(failures, to: output.appendingPathComponent("failures.json"))
		guard !bundles.isEmpty
		else { throw CLIError.operation("No recordings could be exported. \(failures.joined(separator: "\n"))\nResults: \(output.path)") }
		var merged: PublicationOptions = .init(imageWidth: nil)
		if configuration.archive != false, configuration.storage == nil {
			merged.archive = output.appendingPathComponent("recording.pyx").path
		}
		// Images are already prepared per device; merging must not recompress them.
		let document: PyxisMapDocument = try await merged.publish(inputs: bundles, to: output.appendingPathComponent("bundle"))
		let report: RecordingCoverageReport = .init(document: document, configuration: configuration.coverage, plan: plan)
		try writeJSON(report, to: output.appendingPathComponent("coverage.json"))
		printProgress("Published \(document.profiles.count) profiles, \(document.states.count) states and \(document.captures.count) captures.")
		guard failures.isEmpty, report.complete else {
			throw CLIError.operation("Recording is incomplete. \((failures + report.problems).joined(separator: "\n"))\nPartial recording and diagnostics: \(output.path)")
		}
		if let storage = configuration.storage {
			let store: PyxisRecordingStore = .init(root: resolve(storage.path))
			let snapshot: PyxisStoredRecording = try store.update(
				.init(document: document, root: output.appendingPathComponent("bundle")),
				context: storage.context, policy: storage.policy
			)
			try writeJSON([
				"snapshot_id": snapshot.id, "context": storage.context, "path": store.root.path,
			], to: output.appendingPathComponent("storage-result.json"))
			printProgress("Stored snapshot \(snapshot.id) in \(store.root.path) [\(storage.context)].")
			if configuration.archive != false {
				let archive: URL = output.appendingPathComponent("recording.pyx")
				try PyxisArchive().write(snapshot.bundle, to: archive)
				printProgress("Archive: \(archive.path)")
			}
		}
	}

	private func resolve(_ path: String) -> URL {
		URL(fileURLWithPath: path, relativeTo: directory).standardizedFileURL
	}

	private func writeJSON<Value: Encodable>(
		_ value: Value,
		to file: URL
	) throws {
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		try encoder.encode(value).write(to: file, options: .withoutOverwriting)
	}
}
