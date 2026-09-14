import Foundation
import PyxisModel
import PyxisProcessing
import Testing

@Suite
struct PublicationCancellationTests {
	@Test
	func cancelledTransformKeepsLastPublicationAndRemovesStaging() async throws {
		let root = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
			.appendingPathComponent("Format/Fixtures/valid-map")
		let input = try PyxisBundleInput(document: PyxisJSON.decode(Data(contentsOf: root.appendingPathComponent("manifest.json"))), root: root)
		let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: temporary) }
		let output = temporary.appendingPathComponent("bundle")
		let previous = try BundlePublisher.publish(inputs: [input], to: output)
		let manifest = try Data(contentsOf: output.appendingPathComponent("manifest.json"))
		let task = Task {
			try await BundlePublisher.publish(inputs: [input], to: output) { asset, bytes in
				withUnsafeCurrentTask { $0?.cancel() }
				return .init(asset: asset, bytes: bytes)
			}
		}
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(try Data(contentsOf: output.appendingPathComponent("manifest.json")) == manifest)
		try BundleValidator.validate(document: previous, root: output)
		#expect(try FileManager.default.contentsOfDirectory(atPath: temporary.path) == ["bundle"])
	}
}
