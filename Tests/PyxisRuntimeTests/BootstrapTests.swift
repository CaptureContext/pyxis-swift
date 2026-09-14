import Foundation
import Testing
import PyxisCore
import PyxisModel
@testable import PyxisRuntime

@Suite
struct BootstrapTests {
	@Test
	func absentPayloadDoesNothing() async throws {
		#expect(try BootstrapRequest.load(environment: [:]) == nil)
	}

	@Test
	func rejectsUnknownVersionAndMalformedReport() async throws {
		#expect(throws: PyxisBootstrapError.self) {
			try BootstrapRequest.load(environment: [pyxisEnvironmentKey: "{\"version\":2,\"requested\":{}}"])
		}
		#expect(throws: PyxisBootstrapError.self) {
			try PyxisBootstrapReport(encoded: "{\"variants\":{\"appearance\":{\"status\":\"applied\"}}}")
		}
	}

	@Test
	@MainActor
	func adaptersApplyOnlyHandledRequestsAndFailuresRemainVisible() async throws {
		var subscription: String = "production"
		let request = BootstrapRequest(requested: [
			"subscription.status": "trial", "locale": "pl_PL", "accessibility.color_filters": "grayscale", "fixture": "bad",
		])
		let report = try applyPyxisAdapters(requested: request.requested, adapters: [
			"subscription.status": { value in
				subscription = value
				return .init(status: .applied, value: value)
			},
			"fixture": { _ in throw CocoaError(.fileReadUnknown) },
		])
		#expect(subscription == "trial")
		#expect(report.variants["subscription.status"]?.value == "trial")
		#expect(report.variants["locale"]?.status == .unverified)
		#expect(report.variants["accessibility.color_filters"]?.status == .unsupported)
		#expect(report.variants["fixture"]?.status == .unverified)
		#expect(report.variants["fixture"]?.reason?.contains("Adapter failed") == true)
		#expect(try PyxisBootstrapReport(encoded: report.encoded()) == report)
		#expect(try BootstrapRequest.load(environment: [pyxisEnvironmentKey: request.encoded()]) == request)
	}

	@Test
	func missingReportsAreNeverAssumedApplied() async throws {
		let report = PyxisBootstrapReport(variants: ["os": .init(status: .observed, value: "27.0")])
		let covered = report.covering(["color_scheme": "dark"])
		#expect(covered.variants["color_scheme"]?.status == .unverified)
		#expect(covered.variants["os"]?.value == "27.0")
	}
}


extension BootstrapTests {
	@Test
	@MainActor
	func roundtripPreservesSnakeTokensAndOpaquePlatformValues() async throws {
		let requested: PyxisVariants = [
			"accessibility.content_size": "accessibility_large",
			"accessibility.color_filters": "grayscale",
			"subscription.trial_eligibility": "eligible",
			"locale": "pt_BR",
			"device": "iPhone17,3",
			"time_zone": "America/Los_Angeles",
			"custom.fixture": "DemoFixture-v2/Ä",
		]
		let payload = try BootstrapRequest(requested: requested).encoded()
		let loaded = try BootstrapRequest.load(environment: [pyxisEnvironmentKey: payload])
		let decoded = try #require(loaded)
		#expect(decoded.requested == requested)
		let object = try #require(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any])
		#expect(object["requested"] as? [String: String] == requested.dictionary)

		var received: String?
		var report = try applyPyxisAdapters(requested: decoded.requested, adapters: [
			"custom.fixture": { value in
				received = value
				return .init(status: .applied, value: value)
			},
		])
		report.variants["accessibility.reduce_motion"] = .init(status: .observed, value: "true")
		report.variants["accessibility.reduce_transparency"] = .init(status: .observed, value: "false")
		report.variants["accessibility.bold_text"] = .init(status: .observed, value: "false")
		let transported = try PyxisBootstrapReport(encoded: report.encoded())
		#expect(transported == report)
		#expect(received == "DemoFixture-v2/Ä")
		#expect(transported.variants["custom.fixture"]?.value == "DemoFixture-v2/Ä")
		#expect(transported.variants["accessibility.color_filters"]?.status == .unsupported)
		#expect(transported.variants["accessibility.content_size"]?.status == .unverified)
		#expect(transported.variants["locale"]?.status == .unverified)
		#expect(transported.variants["accessibility.reduce_motion"]?.value == "true")
	}

	@Test
	func contentSizeWireTokensRequireDocumentedSpellings() async throws {
		#expect(PyxisVariantEntry.Accessibility.ContentSize.allCases.map(\.rawValue) == [
			"x_small", "small", "medium", "large", "x_large",
			"xx_large", "xxx_large", "accessibility_medium",
			"accessibility_large", "accessibility_x_large",
			"accessibility_xx_large", "accessibility_xxx_large",
		])
		#expect(PyxisVariantEntry.Accessibility.ContentSize(rawValue: "accessibility_large") == .accessibilityLarge)
		for token in ["accessibilityLarge", "extraSmall", "extraExtraLarge", "accessibility_extraLarge", "unknown"] {
			#expect(PyxisVariantEntry.Accessibility.ContentSize(rawValue: token) == nil)
		}
	}
}

#if canImport(UIKit)
import UIKit

extension BootstrapTests {
	@Test
	@MainActor
	func windowAdaptersApplySupportedTokensAndReportUnsupportedValues() async throws {
		let window = UIWindow()
		let adapters = pyxisWindowAdapters(window)
		let applied = try applyPyxisAdapters(
			requested: ["color_scheme": "dark", "accessibility.content_size": "accessibility_large"],
			adapters: adapters
		)
		#expect(applied.variants["accessibility.content_size"]?.status == .applied)
		#expect(window.traitOverrides.preferredContentSizeCategory == .accessibilityLarge)
		#expect(window.overrideUserInterfaceStyle == .dark)

		let unsupported = try applyPyxisAdapters(
			requested: ["color_scheme": "unknown", "accessibility.content_size": "accessibilityLarge"],
			adapters: adapters
		)
		#expect(unsupported.variants["color_scheme"]?.status == .unsupported)
		#expect(unsupported.variants["accessibility.content_size"]?.status == .unsupported)
		#expect(window.traitOverrides.preferredContentSizeCategory == .accessibilityLarge)
		#expect(window.overrideUserInterfaceStyle == .dark)
	}
}
#endif
