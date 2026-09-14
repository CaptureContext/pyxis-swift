import Foundation
import Testing
@testable import pyxis

@Suite
internal struct RecordingTestRunTests {
	@Test(arguments: [1, 2])
	internal func configurationsPreserveBuildPathsAndInjectOnlySelectedVariants(_ version: Int) throws {
		let target: [String: Any] = [
			"BlueprintName": "Tests",
			"TestBundlePath": "__TESTHOST__/Tests.xctest",
			"TestHostPath": "__TESTROOT__/App.app",
			"EnvironmentVariables": ["EXISTING": "kept"],
			"TestingEnvironmentVariables": ["PATHS": "__TESTROOT__/Frameworks:__PLATFORMS__/iOS"],
			"OnlyTestIdentifiers": ["Journeys"],
		]
		var source: [String: Any] = ["__xctestrun_metadata__": ["FormatVersion": version]]
		if version == 1 { source["Tests"] = target }
		else { source["TestConfigurations"] = [["Name": "Base", "IsEnabled": true, "TestTargets": [target]]] }
		let run: RecordingTestRun = try .init(
			data: PropertyListSerialization.data(fromPropertyList: source, format: .binary, options: 0),
			testRoot: URL(fileURLWithPath: "/Built products")
		)
		let data: Data = try run.data(
			selections: [.init(order: 7, values: ["device": "SE 2", "color_scheme": "dark"])],
			environment: ["PYXIS_RUN_ID": "shared-run"]
		)
		let result = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
		let configurations = try #require(result["TestConfigurations"] as? [[String: Any]])
		#expect(configurations.count == 1)
		#expect(configurations[0]["Name"] as? String == "Pyxis-8")
		let targets = try #require(configurations[0]["TestTargets"] as? [[String: Any]])
		#expect(targets[0]["TestHostPath"] as? String == "/Built products/App.app")
		#expect(targets[0]["TestBundlePath"] as? String == "__TESTHOST__/Tests.xctest")
		#expect(targets[0]["OnlyTestIdentifiers"] as? [String] == ["Journeys"])
		let environment = try #require(targets[0]["EnvironmentVariables"] as? [String: String])
		#expect(environment["EXISTING"] == "kept")
		#expect(environment["PYXIS_RUN_ID"] == "shared-run")
		#expect(environment["PYXIS_PROFILE_ORDER"] == "7")
		let variants = try JSONDecoder().decode([String: String].self, from: Data(#require(environment["PYXIS_VARIANTS"]).utf8))
		#expect(variants == ["device": "SE 2", "color_scheme": "dark"])
	}

	@Test
	internal func freshBuildDisambiguatesStaleProductsButCachedReuseRequiresAChoice() throws {
		let directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let old: URL = directory.appendingPathComponent("App_iphonesimulator26.0-arm64.xctestrun")
		let new: URL = directory.appendingPathComponent("App_iphonesimulator27.0-arm64.xctestrun")
		try Data().write(to: old)
		try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: old.path)
		let started: Date = .init()
		try Data().write(to: new)
		#expect(try RecordingTestRun.locate(in: directory, scheme: "App", modifiedAfter: started).standardizedFileURL.path == new.standardizedFileURL.path)
		#expect(throws: (any Error).self) { try RecordingTestRun.locate(in: directory, scheme: "App") }
	}

	@Test
	internal func ambiguousXcodeConfigurationsAreRejected() throws {
		let source: [String: Any] = [
			"__xctestrun_metadata__": ["FormatVersion": 2],
			"TestConfigurations": [["Name": "A", "IsEnabled": true], ["Name": "B", "IsEnabled": true]],
		]
		let data: Data = try PropertyListSerialization.data(fromPropertyList: source, format: .xml, options: 0)
		#expect(throws: (any Error).self) { try RecordingTestRun(data: data, testRoot: URL(fileURLWithPath: "/tmp")) }
	}
}
