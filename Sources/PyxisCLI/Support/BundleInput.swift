import Foundation
import PyxisModel
import PyxisProcessing

internal func loadBundleInput(_ path: String) throws -> PyxisBundleInput {
	let url: URL = .init(fileURLWithPath: path)
	var isDirectory: ObjCBool = false

	guard FileManager.default.fileExists(
		atPath: url.path,
		isDirectory: &isDirectory
	) else {
		throw CLIError.operation("Input does not exist: \(path)")
	}

	let manifest: URL = isDirectory.boolValue
	? url.appendingPathComponent("manifest.json")
	: url

	return try .init(
		document: PyxisJSON.decode(Data(contentsOf: manifest)),
		root: manifest.deletingLastPathComponent()
	)
}
