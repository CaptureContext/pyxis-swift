import Foundation
import Testing
@testable import pyxis

@Suite
struct RecordingConfigurationTests {
	@Test
	func configurationUsesSnakeCaseAndPreservesLiteralArguments() throws {
		let json = """
		{
		  "version": 1,
		  "xcode": {
		    "workspace": "A workspace.xcworkspace", "scheme": "App",
		    "only_testing": ["Tests/Tour"], "build_arguments": ["SETTING=$(literal)"]
		  },
		  "devices": [{"name": "Phone"}, {"name": "Future Phone", "optional": true}],
		  "output": "../artifacts", "derived_data": "../Build data",
		  "images": {"width": 240, "jpeg_quality": 0.5},
		  "variants": {"color_scheme": ["light", "dark"]},
		  "coverage": {"states": ["home"]}
		}
		"""
		let configuration = try JSONDecoder().decode(RecordingConfiguration.self, from: Data(json.utf8))
		try configuration.validate()
		#expect(configuration.xcode.workspace == "A workspace.xcworkspace")
		#expect(configuration.xcode.buildArguments == ["SETTING=$(literal)"])
		#expect(configuration.derivedData == "../Build data")
		#expect(configuration.images?.publication.jpegQuality == 0.5)
		#expect(configuration.devices[1].optional == true)
	}

	@Test
	func invalidConfigurationFailsBeforeExternalToolsRun() throws {
		let invalid: [RecordingConfiguration] = [
			.init(version: 2, xcode: .init(project: "App.xcodeproj", scheme: "App", onlyTesting: ["Tests"]), devices: [.init(name: "Phone")], output: "out"),
			.init(version: 1, xcode: .init(scheme: "App", onlyTesting: ["Tests"]), devices: [.init(name: "Phone")], output: "out"),
			.init(version: 1, xcode: .init(project: "App.xcodeproj", scheme: "App", onlyTesting: []), devices: [.init(name: "Phone")], output: "out"),
			.init(version: 1, xcode: .init(project: "App.xcodeproj", scheme: "App", onlyTesting: ["Tests"]), devices: [], output: "out"),
			.init(version: 1, xcode: .init(project: "App.xcodeproj", scheme: "App", onlyTesting: ["Tests"], testArguments: ["-resultBundlePath", "elsewhere"]), devices: [.init(name: "Phone")], output: "out"),
			.init(version: 1, xcode: .init(project: "App.xcodeproj", scheme: "App", onlyTesting: ["Tests"]), devices: [.init(name: "Phone")], output: "out", images: .init(jpegQuality: 1.5)),
		]
		for configuration in invalid {
			#expect(throws: (any Error).self) { try configuration.validate() }
		}
	}

	@Test
	func deviceResolutionChoosesCompatibleRuntimeAndReportsOptionalDevices() throws {
		let phone: SimulatorDeviceType = .init(name: "Phone", identifier: "phone", modelIdentifier: "Phone1,1")
		let old: SimulatorRuntime = .init(identifier: "ios9", version: "9.0", platform: "iOS", isAvailable: true, supportedDeviceTypes: [phone])
		let new: SimulatorRuntime = .init(identifier: "ios10", version: "10.0", platform: "iOS", isAvailable: true, supportedDeviceTypes: [phone])
		let incompatible: SimulatorRuntime = .init(identifier: "ios99", version: "99.0", platform: "iOS", isAvailable: true, supportedDeviceTypes: [])
		let plan = try RecordingPlan(
			requests: [.init(name: "Phone"), .init(name: "Future Phone", optional: true)],
			deviceTypes: [phone], runtimes: [old, incompatible, new]
		)
		#expect(plan.devices.map(\.runtime) == ["ios10"])
		#expect(plan.skipped.count == 1)
		#expect(throws: (any Error).self) {
			try RecordingPlan(requests: [.init(name: "Missing")], deviceTypes: [phone], runtimes: [old])
		}
		let pinned = try RecordingPlan(requests: [.init(name: "phone", runtime: "9.0")], deviceTypes: [phone], runtimes: [new, old])
		#expect(pinned.devices[0].runtime == "ios9")
	}

	@Test
	func yamlStorageIsOptionalAndCanSkipArchiveCreation() async throws {
		let yaml: String = """
		version: 1
		xcode:
		  project: App.xcodeproj
		  scheme: App
		  only_testing: [Tests]
		devices: [{name: Phone}]
		variants: {}
		output: diagnostics
		"""
		let standalone = try RecordingConfiguration(yaml: yaml)
		try standalone.validate()
		#expect(standalone.storage == nil)
		#expect(standalone.archive == nil)
		let stored = try RecordingConfiguration(yaml: yaml + "\nstorage: {path: '../Shared recordings'}\narchive: false\n")
		try stored.validate()
		#expect(stored.storage?.path == "../Shared recordings")
		#expect(stored.storage?.context == "default")
		#expect(stored.storage?.policy == .merge)
		#expect(stored.archive == false)
		for storage in ["{path: ''}", "{path: store, context: '../elsewhere'}", "{path: store, policy: unknown}"] {
			#expect(throws: (any Error).self) {
				try RecordingConfiguration(yaml: yaml + "\nstorage: \(storage)\n").validate()
			}
		}
	}

	@Test
	func configurationCommandProvidesReadOnlyPlanning() throws {
		let command = try RecordCommand.parse(["--config", "Directory with spaces/pyxis.yaml", "--list"])
		#expect(command.config == "Directory with spaces/pyxis.yaml")
		#expect(command.list)
	}
}
