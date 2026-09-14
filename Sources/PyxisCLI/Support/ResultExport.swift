import Foundation
import PyxisModel
import PyxisProcessing

nonisolated(nonsending)
internal func exportResult(
	_ result: URL,
	to output: URL,
	publication: PublicationOptions
) async throws {
	let scratch: URL = FileManager.default.temporaryDirectory
	.appendingPathComponent("pyxis-export-\(UUID().uuidString)")

	try FileManager.default.createDirectory(
		at: scratch,
		withIntermediateDirectories: true
	)

	defer {
		// Scratch cleanup is best effort; the retained xcresult remains the diagnostic source.
		try? FileManager.default.removeItem(at: scratch)
	}

	let exported: URL = scratch.appendingPathComponent("attachments")
	let status: Int32 = try await runProcess(
		"/usr/bin/xcrun",
		[
			"xcresulttool", "export", "attachments",
			"--path", result.path,
			"--output-path", exported.path,
		],
		log: scratch.appendingPathComponent("export.log")
	)

	guard status == 0 else {
		throw CLIError.operation(
			"xcresulttool attachment export failed (\(status)). Result retained at \(result.path)"
		)
	}

	let tests: [XCResultTestAttachments] = try JSONDecoder().decode(
		[XCResultTestAttachments].self,
		from: Data(contentsOf: exported.appendingPathComponent("manifest.json"))
	)
	var latest: [String: (revision: Int, input: PyxisBundleInput)] = [:]
	var origins: [String: [String]] = [:]

	for test in tests {
		for attachment in test.attachments {
			let name: String = originalAttachmentName(attachment.suggestedHumanReadableName)
			guard name.hasPrefix("pyxis-fragment-"), name.hasSuffix(".json")
			else { continue }
			guard let revision = Int(name.dropLast(5).split(separator: "-").last ?? "")
			else { throw CLIError.operation("Invalid Pyxis fragment revision: \(name)") }

			let attachmentURL: URL = try containedFile(
				attachment.exportedFileName,
				root: exported
			)
			let fragment: PyxisMapDocument = try PyxisJSON.decode(Data(contentsOf: attachmentURL))

			guard
				fragment.format == .fragment,
				let observation = fragment.observations.first
			else {
				throw CLIError.operation("Expected one-observation fragment: \(name)")
			}

			let observationID: String = Data(observation.id.utf8).base64EncodedString()
			let origin: [String] = [
				test.testIdentifier,
				attachment.configurationName,
				attachment.deviceID,
				String(attachment.repetitionNumber ?? 0),
			]

			if let previousOrigin = origins[observationID], previousOrigin != origin {
				throw CLIError.operation(
					"Observation identity reused across test executions; supply distinct attempt/run IDs: \(observation.id)"
				)
			}

			origins[observationID] = origin
			if let previous = latest[observationID], previous.revision > revision { continue }

			if let previous = latest[observationID], previous.revision == revision {
				guard try PyxisJSON.encode(previous.input.document) == PyxisJSON.encode(fragment) else {
					throw CLIError.operation(
						"Conflicting fragment revision for \(observationID); use distinct attempt IDs."
					)
				}
				continue
			}

			let root: URL = scratch.appendingPathComponent(UUID().uuidString)
			try FileManager.default.createDirectory(
				at: root,
				withIntermediateDirectories: true
			)
			var copiedPaths: Set<Data> = []

			for capture in fragment.captures {
				guard copiedPaths.insert(Data(capture.asset.path.utf8)).inserted
				else { continue }

				let expected: String = URL(fileURLWithPath: capture.asset.path).lastPathComponent
				let matches: [XCResultAttachment] = test.attachments.filter {
					originalAttachmentName($0.suggestedHumanReadableName) == expected
					&& $0.configurationName == attachment.configurationName
					&& $0.deviceID == attachment.deviceID
					&& $0.repetitionNumber == attachment.repetitionNumber
				}

				guard
					matches.count == 1,
					let image = matches.first
				else {
					throw CLIError.operation(
						"Missing or ambiguous screenshot \(expected) in \(test.testIdentifier)"
					)
				}

				let destination: URL = try containedFile(capture.asset.path, root: root)
				try FileManager.default.createDirectory(
					at: destination.deletingLastPathComponent(),
					withIntermediateDirectories: true
				)
				try FileManager.default.copyItem(
					at: containedFile(image.exportedFileName, root: exported),
					to: destination
				)
			}

			latest[observationID] = (revision, .init(document: fragment, root: root))
		}
	}

	guard !latest.isEmpty
	else { throw CLIError.operation("No Pyxis fragments found in \(result.path)") }

	let document: PyxisMapDocument = try await publication.publish(
		inputs: latest.values.map(\.input),
		to: output
	)
	print("Exported \(document.observations.count) observations to \(output.path)")
}

private func containedFile(
	_ path: String,
	root: URL
) throws -> URL {
	let allowed: CharacterSet = .init(
		charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
	)
	let components: [Substring] = path.split(
		separator: "/",
		omittingEmptySubsequences: false
	)
	let hasSafeSegments: Bool = components.allSatisfy {
		!$0.isEmpty
		&& $0 != "."
		&& $0 != ".."
		&& $0.unicodeScalars.allSatisfy(allowed.contains)
	}

	guard !components.isEmpty, hasSafeSegments
	else { throw CLIError.operation("Unsafe attachment path: \(path)") }

	let url: URL = root.appendingPathComponent(path).resolvingSymlinksInPath()
	let canonicalRoot: String = root.resolvingSymlinksInPath().path + "/"

	guard url.path.hasPrefix(canonicalRoot)
	else { throw CLIError.operation("XCResultAttachment escapes its root: \(path)") }
	return url
}

private func originalAttachmentName(_ suggestedName: String) -> String {
	// xcresulttool appends its index and UUID before the extension.
	let pattern: String = "_[0-9]+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?=\\.[^.]+$)"
	return suggestedName.replacingOccurrences(
		of: pattern,
		with: "",
		options: .regularExpression
	)
}
