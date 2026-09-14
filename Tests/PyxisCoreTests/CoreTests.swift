import Foundation
import PyxisModel
import PyxisProcessing
import Testing

@Suite
struct PyxisCoreTests {
	private let fixtures: URL = URL(fileURLWithPath: #filePath)
		.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
		.appendingPathComponent("Format/Fixtures")

	@Test
	func formatFixtures() async throws {
		for name in ["valid-map", "valid-fragment"] {
			let root = fixtures.appendingPathComponent(name)
			let document = try PyxisJSON.decode(Data(contentsOf: root.appendingPathComponent("manifest.json")))
			try BundleValidator.validate(document: document, root: root)
			#expect(document.captures.count == 3)
			#expect(document.transitions.last?.status == .failed)
		}
		let invalid = try FileManager.default.contentsOfDirectory(
			at: fixtures.appendingPathComponent("invalid"),
			includingPropertiesForKeys: nil
		)
		#expect(invalid.count >= 19)
		for url in invalid {
			let data = try Data(contentsOf: url)
			#expect(throws: (any Error).self, "\(url.lastPathComponent)") { try PyxisJSON.decode(data) }
		}
	}

	@Test
	func stableIdentityUsesFramedUTF8() async throws {
		struct Vector: Decodable {
			let parts: [String]
			let sha256: String
		}
		let data = try Data(contentsOf: fixtures.appendingPathComponent("identity-vectors.json"))
		let vectors = try JSONDecoder().decode([Vector].self, from: data)
		for vector in vectors { #expect(StableID.digest(parts: vector.parts) == vector.sha256) }
		#expect(StableID.capture(observationID: "o_α", stateID: "detail.🌙", occurrence: 0)
			== "c_4baa7486f51221d35578ad2682dbc2f6bb4d5a6a7bd7cf94cfd0bde1dd3b2072")
	}

	@Test
	func mergePreservesExecutionsAndRejectsConflicts() async throws {
		let first = try fixture("valid-fragment")
		var second = first
		second.observations[0].id = "o_second"
		for index in second.captures.indices {
			second.captures[index].id += "_second"
			second.captures[index].observationID = "o_second"
		}
		for index in second.transitions.indices {
			second.transitions[index].id += "_second"
			second.transitions[index].observationID = "o_second"
		}
		let forward = try MapMerger.merge([first, second, first])
		let reverse = try MapMerger.merge([second, first])
		#expect(try PyxisJSON.encode(forward) == PyxisJSON.encode(reverse))
		#expect(forward.observations.count == 2)
		#expect(forward.captures.count == 6)
		second.states[0].title = "Conflicting title"
		#expect(throws: PyxisValidationError.self) { try MapMerger.merge([first, second]) }
		second = first
		second.run.id = "another-run"
		#expect(throws: PyxisValidationError.self) { try MapMerger.merge([first, second]) }
	}

	@Test
	func publicationPreservesLastMapOnInvalidInput() async throws {
		let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
		defer { try! FileManager.default.removeItem(at: temporary) }
		let output = temporary.appendingPathComponent("output")
		let source = fixtures.appendingPathComponent("valid-fragment")
		let input = try PyxisBundleInput(document: fixture("valid-fragment"), root: source)
		let first = try BundlePublisher.publish(inputs: [input], to: output)
		try BundleValidator.validate(document: first, root: output)
		#expect(first.captures.count == 3)
		#expect(first.captures.allSatisfy { $0.asset.sha256 != nil })
		let original = try Data(contentsOf: output.appendingPathComponent("manifest.json"))
		var corrupt = input
		for index in corrupt.document.captures.indices {
			corrupt.document.captures[index].asset.sha256 = String(repeating: "0", count: 64)
		}
		#expect(throws: PyxisValidationError.self) { try BundlePublisher.publish(inputs: [corrupt], to: output) }
		#expect(try Data(contentsOf: output.appendingPathComponent("manifest.json")) == original)
		_ = try BundlePublisher.publish(inputs: [input], to: output)
		#expect(try Data(contentsOf: output.appendingPathComponent("manifest.json")) == original)
		try Data("personal notes".utf8).write(to: output.appendingPathComponent("notes.txt"))
		#expect(throws: PyxisValidationError.self) { try BundlePublisher.publish(inputs: [input], to: output) }
		#expect(try Data(contentsOf: output.appendingPathComponent("notes.txt")) == Data("personal notes".utf8))
		#expect(throws: PyxisValidationError.self) { try BundlePublisher.publish(inputs: [input], to: source) }
	}

	@Test
	func rejectsSymlinkEscapeAndCorruptPixels() async throws {
		let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: temporary.appendingPathComponent("bundle/assets"), withIntermediateDirectories: true)
		defer { try! FileManager.default.removeItem(at: temporary) }
		let png = fixtures.appendingPathComponent("valid-map/assets/example.png")
		let outside = temporary.appendingPathComponent("outside.png")
		try FileManager.default.copyItem(at: png, to: outside)
		try FileManager.default.createSymbolicLink(
			at: temporary.appendingPathComponent("bundle/assets/example.png"),
			withDestinationURL: outside
		)
		let document = try fixture("valid-map")
		#expect(throws: PyxisValidationError.self) {
			try BundleValidator.validate(document: document, root: temporary.appendingPathComponent("bundle"))
		}
		var asset = document.captures[0].asset
		asset.width = 100
		#expect(throws: PyxisValidationError.self) {
			try BundleValidator.assetData(asset, root: fixtures.appendingPathComponent("valid-map"))
		}
		asset.width = 2
		asset.mediaType = .jpeg
		#expect(throws: PyxisValidationError.self) {
			try BundleValidator.assetData(asset, root: fixtures.appendingPathComponent("valid-map"))
		}
	}

	@Test
	func unicodeIdentityValidation() async throws {
		var document = try fixture("valid-map")
		document.states.append(PyxisState(id: "é", screenID: "unicode", domainID: "main", title: "Composed"))
		document.states.append(PyxisState(id: "e\u{301}", screenID: "unicode", domainID: "main", title: "Decomposed"))
		try PyxisValidation.validate(document)
		let merged = try MapMerger.merge([document])
		#expect(merged.states.count == 5)
	}

	@Test
	func ignoresUnknownFieldsAndRejectsDuplicateKeys() async throws {
		let data = try Data(contentsOf: fixtures.appendingPathComponent("valid-map/manifest.json"))
		var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		json["futureField"] = ["nested": NSNull()]
		_ = try PyxisJSON.decode(JSONSerialization.data(withJSONObject: json))
		let text = try #require(String(data: data, encoding: .utf8))
		let duplicate = text.replacingOccurrences(of: "\"version\": 1", with: "\"version\": 1, \"ver\\u0073ion\": 1")
		#expect(throws: PyxisValidationError.self) { try PyxisJSON.decode(Data(duplicate.utf8)) }
	}

	private func fixture(_ name: String) throws -> PyxisMapDocument {
		try PyxisJSON.decode(Data(contentsOf: fixtures.appendingPathComponent(name + "/manifest.json")))
	}
}
