import Foundation
import XCTest
import ExampleTesting

internal extension ExampleProfile {
	init(recordingEnvironment environment: [String: String]) throws {
		let environment: PyxisRecordingEnvironment = try .init(environment: environment)
		guard let values = environment.variants else {
			self.init()
			return
		}
		func decode<Value: RawRepresentable>(
			_ type: Value.Type,
			for key: String
		) throws -> Value where Value.RawValue == String {
			guard let rawValue = values[key], let value = Value(rawValue: rawValue)
			else {
				throw DecodingError.dataCorrupted(.init(
					codingPath: [],
					debugDescription: "Missing or unsupported example variant: \(key)"
				))
			}
			return value
		}
		try self.init(
			colorScheme: decode(ColorScheme.self, for: PyxisVariantEntry.colorSchemeKey),
			direction: decode(LayoutDirection.self, for: PyxisVariantEntry.layoutDirectionKey),
			contentSize: decode(ContentSize.self, for: PyxisVariantEntry.accessibilityContentSizeKey)
		)
		XCTAssertEqual(values[PyxisVariantEntry.deviceKey], environment.deviceName)
		XCTAssertEqual(values[PyxisVariantEntry.subscriptionKey], ExampleSubscription.trial.rawValue)
	}

	var recording: PyxisProfile {
		get throws { try recording(environment: .init(environment: ProcessInfo.processInfo.environment)) }
	}

	func recording(environment: PyxisRecordingEnvironment) -> PyxisProfile {
		let model: String = environment.deviceModel ?? ExampleDevice.simulatorModel ?? "unknown"
		let name: String = environment.deviceName ?? ExampleDevice.name(for: model)
		let order: Int = environment.profileOrder
		?? (name == ExampleDevice.iPhone18Pro.rawValue ? 0 : 8) + (colorScheme == .dark ? 0 : 4)
		+ (direction == .ltr ? 0 : 2) + (contentSize == .large ? 0 : 1)
		let sizeTitle: String = contentSize == .xxxLarge ? "XXXL" : contentSize.rawValue.capitalized
		return .init(
			id: [name, colorScheme.rawValue, direction.rawValue, contentSize.rawValue].joined(separator: "."),
			title: "\(name) · \(colorScheme.rawValue.capitalized) · \(direction.rawValue.uppercased()) · \(sizeTitle)",
			requested: [
				.device(name),
				.colorScheme(colorScheme),
				.layoutDirection(direction),
				.accessibility(.contentSize(contentSize)),
				.subscription(.trial),
			],
			order: order
		)
	}
}
