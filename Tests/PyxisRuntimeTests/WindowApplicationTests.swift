import Testing
import PyxisCore
@testable import PyxisRuntime

@Suite
@MainActor
struct WindowApplicationTests {
	private enum WindowLabelKey: PyxisConfigurationKey {
		static var defaultValue: String { "default" }
	}

	private enum Failure: Error { case unavailable }

	@Test
	func unpreparedConfigurationDoesNotInvokeAdapters() async throws {
		var configuration = PyxisConfiguration()
		configuration.requested = ["color_scheme": "dark"]
		var invoked = false
		let report = try applyPyxisWindowAdapters(configuration: configuration, adapters: [
			"color_scheme": { value in
				invoked = true
				return .init(status: .applied, value: value)
			},
		])
		#expect(report == nil)
		#expect(!invoked)
	}

	@Test
	func eachWindowHasIndependentResultsWithoutRepeatingProcessAdapters() async throws {
		let storage = PyxisStorage()
		var processCalls = 0
		let processReport = try preparePyxis(
			environment: [pyxisEnvironmentKey: BootstrapRequest(requested: [
				"color_scheme": "dark", "subscription.status": "trial", "locale": "en_US",
			]).encoded()],
			adapters: ["subscription.status": { value in
				processCalls += 1
				return .init(status: .applied, value: value)
			}],
			storage: storage
		)
		let snapshot = storage.current
		var firstWindowCalls = 0
		let firstAdapters: [String: PyxisAdapter] = ["color_scheme": { value in
			firstWindowCalls += 1
			return .init(status: .applied, value: value)
		}]
		let first = try applyPyxisWindowAdapters(configuration: snapshot, adapters: firstAdapters)
		let second = try applyPyxisWindowAdapters(configuration: snapshot, adapters: [
			"color_scheme": { _ in .init(status: .unsupported, reason: "Window owns its appearance") },
		])
		let repeated = try applyPyxisWindowAdapters(configuration: snapshot, adapters: firstAdapters)
		#expect(first?.variants["color_scheme"]?.status == .applied)
		#expect(second?.variants["color_scheme"]?.status == .unsupported)
		#expect(repeated == first)
		#expect(firstWindowCalls == 2)
		#expect(processCalls == 1)
		#expect(first?.variants["subscription.status"]?.value == "trial")
		#expect(second?.variants["subscription.status"]?.value == "trial")
		#expect(first?.variants["locale"] == processReport?.variants["locale"])
		#expect(snapshot.report == processReport)
		#expect(storage.current.report == processReport)
		#expect(storage.current.report?.variants["color_scheme"]?.status == .unverified)
	}

	@Test
	func adaptersReadSuppliedSnapshotAndUnrequestedAdaptersDoNotRun() async throws {
		var configuration = PyxisConfiguration()
		configuration.requested = ["color_scheme": "dark"]
		configuration.report = .init(variants: [:]).covering(configuration.requested)
		configuration[WindowLabelKey.self] = "window"
		let report = try withPyxis({ $0[WindowLabelKey.self] = "outer" }) {
			let report = try applyPyxisWindowAdapters(configuration: configuration, adapters: [
				"color_scheme": { value in
					#expect(pyxisConfiguration[WindowLabelKey.self] == "window")
					return .init(status: .applied, value: value)
				},
				"unrequested": { _ in
					Issue.record("An unrequested window adapter ran")
					throw Failure.unavailable
				},
			])
			#expect(pyxisConfiguration[WindowLabelKey.self] == "outer")
			return report
		}
		#expect(report?.variants["color_scheme"]?.status == .applied)
		#expect(pyxisConfiguration[WindowLabelKey.self] == "default")
	}

	@Test
	func windowFailuresReplaceStaleSuccessOnlyInReturnedReport() async throws {
		var configuration = PyxisConfiguration()
		configuration.requested = ["color_scheme": "dark"]
		configuration.report = .init(variants: ["color_scheme": .init(status: .applied, value: "dark")])
		let failed = try applyPyxisWindowAdapters(configuration: configuration, adapters: [
			"color_scheme": { _ in throw Failure.unavailable },
		])
		#expect(failed?.variants["color_scheme"]?.status == .unverified)
		#expect(failed?.variants["color_scheme"]?.value == nil)
		#expect(configuration.report?.variants["color_scheme"]?.status == .applied)
		#expect(throws: PyxisBootstrapError.invalidReport("color_scheme")) {
			try applyPyxisWindowAdapters(configuration: configuration, adapters: [
				"color_scheme": { _ in .init(status: .applied) },
			])
		}
	}
}
