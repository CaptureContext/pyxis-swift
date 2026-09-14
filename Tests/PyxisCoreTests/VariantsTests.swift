import Foundation
import Testing
import PyxisModel

@Suite
struct VariantsTests {
	@Test
	func composableEntriesEncodeAsAnObjectAndPreserveCustomValues() throws {
		let variants: PyxisVariants = [
			.colorScheme(.dark),
			.layoutDirection(.rtl),
			.accessibility(.contentSize(.xxxLarge)),
			.accessibility(.contrast(.high)),
			.init(key: "custom.CamelKey", value: "CamelValue"),
		]
		let data: Data = try JSONEncoder().encode(variants)
		let object: [String: String] = try JSONDecoder().decode([String: String].self, from: data)
		#expect(object == [
			"color_scheme": "dark",
			"layout_direction": "rtl",
			"accessibility.content_size": "xxx_large",
			"accessibility.contrast": "high",
			"custom.CamelKey": "CamelValue",
		])
		#expect(try JSONDecoder().decode(PyxisVariants.self, from: data) == variants)
	}

	@Test
	func overridesReplaceTheSameKeyWithoutChangingTheOriginal() {
		let original: PyxisVariants = [.colorScheme(.light), .device("Phone")]
		var copy: PyxisVariants = original.merging([.colorScheme(.dark)])
		copy.set(.accessibility(.contentSize(.large)))
		#expect(original[PyxisVariantEntry.colorSchemeKey] == "light")
		#expect(copy[PyxisVariantEntry.colorSchemeKey] == "dark")
		#expect(copy[PyxisVariantEntry.deviceKey] == "Phone")
		#expect(copy.count == 3)
		let repeated: PyxisVariants = [.colorScheme(.light), .colorScheme(.dark)]
		#expect(repeated == [.colorScheme(.dark)])
	}

	@Test
	func declarationOrderSurvivesOverridesAndFiltering() throws {
		let original: PyxisVariants = [.layoutDirection(.rtl), .colorScheme(.light)]
		var variants = original.merging([.colorScheme(.dark), .device("Phone")])
		variants.set(.layoutDirection(.ltr))
		#expect(Array(variants.keys) == ["layout_direction", "color_scheme", "device"])
		#expect(variants.map(\.key) == Array(variants.keys))
		#expect(Array(variants.filter { $0.key != "color_scheme" }.keys) == ["layout_direction", "device"])
		var visited: [String] = []
		_ = variants.mapValues { visited.append($0); return $0 }
		#expect(visited == ["ltr", "dark", "Phone"])
		let reversed: PyxisVariants = [.device("Phone"), .colorScheme(.dark), .layoutDirection(.ltr)]
		#expect(variants == reversed)
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.sortedKeys]
		#expect(try encoder.encode(variants) == encoder.encode(reversed))
	}

	@Test
	func unorderedInputsAreSorted() throws {
		let literal: PyxisVariants = ["z": "last", "a": "first"]
		#expect(Array(literal.keys) == ["z", "a"])
		let dictionary: [String: String] = ["z": "last", "a": "first"]
		#expect(Array(PyxisVariants(dictionary).keys) == ["a", "z"])
		let decoded = try JSONDecoder().decode(PyxisVariants.self, from: Data(#"{"z":"last","a":"first"}"#.utf8))
		#expect(Array(decoded.keys) == ["a", "z"])
	}

	@Test(arguments: ["null", "[]", "{\"color_scheme\":null}", "{\"color_scheme\":42}"])
	func malformedVariantObjectsAreRejected(_ json: String) {
		#expect(throws: (any Error).self) {
			try JSONDecoder().decode(PyxisVariants.self, from: Data(json.utf8))
		}
	}
}
