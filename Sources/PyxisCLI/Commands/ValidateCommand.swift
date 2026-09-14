import ArgumentParser
import Foundation
import PyxisProcessing

internal struct ValidateCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "validate",
		abstract: "Validate a manifest and all referenced images."
	)

	@Argument(help: "Bundle directory, manifest JSON, .pyx or ZIP file to validate.")
	internal var path: String

	internal init() {}

	internal func validate() throws {
		try requireNonempty(self.path, name: "path")
	}

	internal func run() throws {
		let session: BundleInputSession = try .init(paths: [path])
		defer { withExtendedLifetime(session) {} }
		let bundle: PyxisBundleInput = session.inputs[0]
		try BundleValidator.validate(document: bundle.document, root: bundle.root)
		print("Valid \(bundle.document.format.rawValue): \(bundle.document.captures.count) captures")
	}
}
