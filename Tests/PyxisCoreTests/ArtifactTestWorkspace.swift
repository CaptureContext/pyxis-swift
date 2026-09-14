import Foundation
import PyxisModel
import PyxisProcessing

final class ArtifactTestWorkspace {
	let root: URL
	let fixture: URL

	init() throws {
		self.root = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-artifact-test-\(UUID().uuidString)")
		self.fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
			.deletingLastPathComponent().appendingPathComponent("Format/Fixtures/valid-map")
		try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
	}

	deinit { try? FileManager.default.removeItem(at: root) }

	func recording(_ id: String, appearance: String = "dark", journey: String = "notes") throws -> PyxisBundleInput {
		var document: PyxisMapDocument = try PyxisJSON.decode(Data(contentsOf: fixture.appendingPathComponent("manifest.json")))
		document.run = .init(id: id, createdAt: Date(timeIntervalSince1970: 1_700_000_000), provenance: ["revision": id])
		document.states = Array(document.states.prefix(2))
		document.profiles = [.init(id: appearance, title: appearance, requested: ["color_scheme": appearance])]
		document.observations = [.init(id: "o_" + id, journeyID: journey, title: journey, testName: "test" + journey, profileID: appearance, status: .passed, variants: ["color_scheme": .init(status: .applied, value: appearance)])]
		for index in document.captures.indices {
			document.captures[index].id = "\(id)_capture_\(index)"
			document.captures[index].observationID = "o_" + id
		}
		document.transitions = Array(document.transitions.prefix(1))
		document.transitions[0].id = id + "_transition"
		document.transitions[0].observationID = "o_" + id
		let output: URL = root.appendingPathComponent(id)
		let published: PyxisMapDocument = try BundlePublisher.publish(inputs: [.init(document: document, root: fixture)], to: output)
		return .init(document: published, root: output)
	}
}
