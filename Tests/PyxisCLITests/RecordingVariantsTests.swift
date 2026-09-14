import Foundation
import Testing
@testable import pyxis

@Suite
internal struct RecordingVariantsTests {
	private let prefix: String = """
	version: 1
	xcode:
	  project: App.xcodeproj
	  scheme: App
	  only_testing: [Tests/Journeys]
	devices:
	  - name: Pro
	  - name: SE 2
	    simulator: iPhone SE (2nd generation)
	output: recordings
	"""

	@Test
	internal func yamlMatrixExpandsAxesWithFirstValuesAsDefault() throws {
		let config: RecordingConfiguration = try .init(yaml: prefix + """

		variants:
		  color_scheme: [dark, light]
		  layout_direction: [ltr, rtl]
		""")
		try config.validate()
		let combinations: [[String: String]] = config.variants.combinations(deviceNames: config.devices.map(\.name))
		#expect(combinations.count == 8)
		#expect(combinations.first == ["device": "Pro", "color_scheme": "dark", "layout_direction": "ltr"])
		#expect(config.devices[1].simulator == "iPhone SE (2nd generation)")
	}

	@Test
	internal func yamlListPreservesOnlySelectedCombinationsAndOrder() throws {
		let config: RecordingConfiguration = try .init(yaml: prefix + """

		variants:
		  - color_scheme: dark
		    layout_direction: ltr
		  - device: Pro
		    color_scheme: light
		    layout_direction: rtl
		""")
		try config.validate()
		let combinations: [[String: String]] = config.variants.combinations(deviceNames: ["Pro", "SE 2"])
		#expect(combinations.count == 3)
		#expect(combinations[2] == ["device": "Pro", "color_scheme": "light", "layout_direction": "rtl"])
		#expect(!combinations.contains { $0["device"] == "SE 2" && $0["color_scheme"] == "light" })
	}

	@Test(arguments: [
		"[]", "{color_scheme: []}", "{color_scheme: [dark, dark]}", "{color_scheme: dark}",
		"[{color_scheme: [dark]}]", "[{device: Unknown}]", "[{color_scheme: dark}, {device: Pro, color_scheme: dark}]",
	])
	internal func invalidVariantsFailBeforeRunningTools(_ yaml: String) {
		#expect(throws: (any Error).self) {
			try RecordingConfiguration(yaml: prefix + "\nvariants: " + yaml).validate()
		}
	}

	@Test
	internal func yamlAnchorsShareValuesWithoutExpandingAList() throws {
		let config: RecordingConfiguration = try .init(yaml: prefix + """

		variants:
		  - &base
		    device: Pro
		    color_scheme: dark
		    layout_direction: ltr
		  - <<: *base
		    color_scheme: light
		""")
		try config.validate()
		#expect(config.variants.combinations(deviceNames: ["Pro", "SE 2"]) == [
			["device": "Pro", "color_scheme": "dark", "layout_direction": "ltr"],
			["device": "Pro", "color_scheme": "light", "layout_direction": "ltr"],
		])
	}

	@Test
	internal func deviceResolutionDoesNotRequireUnselectedDevices() throws {
		let phone: SimulatorDeviceType = .init(name: "Actual SE", identifier: "se", modelIdentifier: "Phone1,1")
		let runtime: SimulatorRuntime = .init(identifier: "ios", version: "27", platform: "iOS", isAvailable: true, supportedDeviceTypes: [phone])
		let plan: RecordingPlan = try .init(
			requests: [.init(name: "Unavailable Pro"), .init(name: "SE 2", simulator: "Actual SE")],
			deviceTypes: [phone], runtimes: [runtime],
			variants: .configurations([["device": "SE 2", "color_scheme": "dark"]])
		)
		#expect(plan.devices.map(\.name) == ["SE 2"])
		#expect(plan.selections.map(\.values) == [["device": "SE 2", "color_scheme": "dark"]])
	}
}
