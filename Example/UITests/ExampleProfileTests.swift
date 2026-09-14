import ExampleTesting
import Foundation
import XCTest

internal final class ExampleProfileTests: XCTestCase {
	internal func testDefaultsPreserveThePublishedProfile() async throws {
		let profile: ExampleProfile = try .init(recordingEnvironment: [:])
		XCTAssertEqual(profile, .init(colorScheme: .dark, direction: .ltr, contentSize: .large))
		let recording: PyxisProfile = profile.recording(environment: .init(deviceName: ExampleDevice.iPhone18Pro.rawValue))
		XCTAssertEqual(recording.id, "iPhone 18 Pro.dark.ltr.large")
		XCTAssertEqual(recording.title, "iPhone 18 Pro · Dark · LTR · Large")
		XCTAssertEqual(recording.order, 0)
		XCTAssertEqual(recording.requested, [
			"device": "iPhone 18 Pro",
			"color_scheme": "dark",
			"layout_direction": "ltr",
			"accessibility.content_size": "large",
			"subscription.status": "trial",
		])
	}

	internal func testAllExampleCombinationsRoundTripThroughTheRunnerEnvironment() async throws {
		var orders: Set<Int> = []
		for colorScheme: ExampleProfile.ColorScheme in [.dark, .light] {
			for direction in ExampleProfile.LayoutDirection.allCases {
				for size: ExampleProfile.ContentSize in [.large, .xxxLarge] {
					let profile: ExampleProfile = .init(colorScheme: colorScheme, direction: direction, contentSize: size)
					var environment: PyxisRecordingEnvironment = .init(deviceName: ExampleDevice.iPhone18Pro.rawValue)
					let recording: PyxisProfile = profile.recording(environment: environment)
					environment.variants = recording.requested
					XCTAssertEqual(try ExampleProfile(recordingEnvironment: environment.encoded()), profile)
					orders.insert(recording.order)
				}
			}
		}
		XCTAssertEqual(orders, Set(0..<8))
		let recording: PyxisProfile = ExampleProfile(colorScheme: .light, direction: .rtl, contentSize: .xxxLarge)
			.recording(environment: .init(profileOrder: 23, deviceName: ExampleDevice.iPhoneSE2.rawValue))
		XCTAssertEqual(recording.id, "iPhone SE 2.light.rtl.xxx_large")
		XCTAssertEqual(recording.title, "iPhone SE 2 · Light · RTL · XXXL")
		XCTAssertEqual(recording.order, 23)
	}

	internal func testMissingAndUnknownVariantsFailDecoding() async throws {
		let recording: PyxisProfile = ExampleProfile().recording(environment: .init())
		let keys: [String] = [
			PyxisVariantEntry.colorSchemeKey,
			PyxisVariantEntry.layoutDirectionKey,
			PyxisVariantEntry.accessibilityContentSizeKey,
		]
		for key in keys {
			for value in [nil, "unsupported"] as [String?] {
				var values: PyxisVariants = recording.requested
				values[key] = value
				let encoded: String = try String(decoding: JSONEncoder().encode(values), as: UTF8.self)
				XCTAssertThrowsError(try ExampleProfile(recordingEnvironment: [
					PyxisRecordingEnvironment.Key.variants.rawValue: encoded,
				]))
			}
		}
	}

	internal func testIdentifiersAndJourneysRetainTheirWireValues() async throws {
		XCTAssertEqual(ExampleElement.ready(.home).identifier, "home.ready")
		XCTAssertEqual(ExampleElement.openDetail.identifier, "open.detail")
		XCTAssertEqual(ExampleElement.report.identifier, "pyxis.bootstrap.report")
		XCTAssertEqual(ExampleJourney.writeNote.rawValue, "write-note")
		XCTAssertEqual(ExampleJourney.writeNote.title, "Make room for a new idea")
		XCTAssertEqual(ExampleJourney.discoverPlus.rawValue, "discover-plus")
		XCTAssertEqual(ExampleDevice.name(for: ExampleDevice.iPhoneSE2.modelIdentifier), "iPhone SE 2")
		XCTAssertEqual(ExampleDevice.name(for: "future-device"), "future-device")
	}
}
