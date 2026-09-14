import PyxisModel
import Testing
import PyxisCore
@testable import PyxisRuntime

@Suite
@MainActor
struct PreparationTests {
	private enum FixtureKey: PyxisConfigurationKey {
		static var defaultValue: String { "production" }
	}

	private enum PublicPreparationKey: PyxisConfigurationKey {
		static var defaultValue: String { "unprepared" }
	}

	private enum Failure: Error {
		case configuration
	}

	@Test
	func absentPayloadDoesNotConfigureOrConsumePreparation() async throws {
		let storage = PyxisStorage()
		var configured: Bool = false
		let absent = try preparePyxis(
			environment: [:],
			configure: { _ in configured = true },
			storage: storage
		)
		#expect(absent == nil)
		#expect(!configured)
		#expect(storage.current.report == nil)

		let report = try preparePyxis(environment: environment(), storage: storage)
		#expect(report != nil)
		#expect(storage.current.report == report)
	}

	@Test
	func invalidPayloadAndConfigurationFailuresAllowRetry() async throws {
		let storage = PyxisStorage()
		#expect(throws: (any Error).self) {
			try preparePyxis(environment: [pyxisEnvironmentKey: "invalid"], storage: storage)
		}
		#expect(throws: PyxisBootstrapError.unsupportedVersion(2)) {
			try preparePyxis(
				environment: [pyxisEnvironmentKey: "{\"version\":2,\"requested\":{}}"],
				storage: storage
			)
		}
		#expect(throws: Failure.self) {
			try preparePyxis(
				environment: environment(["fixture": "demo"]),
				configure: {
					$0[FixtureKey.self] = "partial"
					throw Failure.configuration
				},
				storage: storage
			)
		}
		#expect(storage.current[FixtureKey.self] == "production")
		#expect(storage.current.requested.isEmpty)
		#expect(storage.current.report == nil)

		let report = try preparePyxis(environment: environment(), storage: storage)
		#expect(report != nil)
	}

	@Test
	func adaptersReadStagedConfigurationAndReportIsCommitted() async throws {
		let storage = PyxisStorage()
		let requested: PyxisVariants = ["fixture": "demo"]
		let report = try preparePyxis(
			environment: environment(requested),
			adapters: [
				"fixture": { value in
					#expect(pyxisConfiguration[FixtureKey.self] == "configured")
					#expect(pyxisConfiguration.requested == requested)
					#expect(pyxisConfiguration.report == nil)
					#expect(storage.current[FixtureKey.self] == "production")
					return .init(status: .applied, value: value)
				},
			],
			configure: { $0[FixtureKey.self] = "configured" },
			storage: storage
		)
		#expect(storage.current[FixtureKey.self] == "configured")
		#expect(storage.current.requested == requested)
		#expect(storage.current.report == report)
		#expect(report?.variants["fixture"]?.value == "demo")
		#expect(pyxisConfiguration[FixtureKey.self] == "production")
	}

	@Test
	func duplicateAndReentrantPreparationCannotReplaceConfiguration() async throws {
		let storage = PyxisStorage()
		let payload = try environment()
		let _ = try preparePyxis(
			environment: payload,
			configure: {
				#expect(throws: PyxisBootstrapError.preparationInProgress) {
					try preparePyxis(environment: payload, storage: storage)
				}
				$0[FixtureKey.self] = "first"
			},
			storage: storage
		)
		#expect(throws: PyxisBootstrapError.alreadyPrepared) {
			try preparePyxis(
				environment: payload,
				configure: { $0[FixtureKey.self] = "second" },
				storage: storage
			)
		}
		#expect(storage.current[FixtureKey.self] == "first")
	}

	@Test
	func invalidAdapterReportDoesNotPublishAndAllowsRetry() async throws {
		let storage = PyxisStorage()
		let payload = try environment(["fixture": "demo"])
		#expect(throws: PyxisBootstrapError.invalidReport("fixture")) {
			try preparePyxis(
				environment: payload,
				adapters: ["fixture": { _ in .init(status: .applied) }],
				storage: storage
			)
		}
		#expect(storage.current.report == nil)
		#expect(storage.current.requested.isEmpty)
		let report = try preparePyxis(environment: payload, storage: storage)
		#expect(report?.variants["fixture"]?.status == .unverified)
	}

	@Test
	func publicPreparationPublishesDefaultWithoutScopedMutation() async throws {
		let report = try preparePyxis(
			environment: environment(),
			configure: { $0[PublicPreparationKey.self] = "prepared" }
		)
		#expect(pyxisConfiguration[PublicPreparationKey.self] == "prepared")
		#expect(pyxisConfiguration.report == report)

		withPyxis {
			$0[PublicPreparationKey.self] = "temporary"
		} operation: {
			#expect(pyxisConfiguration[PublicPreparationKey.self] == "temporary")
		}
		#expect(pyxisConfiguration[PublicPreparationKey.self] == "prepared")
	}

	private func environment(_ requested: PyxisVariants = [:]) throws -> [String: String] {
		try [pyxisEnvironmentKey: BootstrapRequest(requested: requested).encoded()]
	}
}
