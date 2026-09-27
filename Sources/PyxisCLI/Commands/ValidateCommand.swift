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
		for bundle in session.inputs {
			try BundleValidator.validate(document: bundle.document, root: bundle.root)
		}
		print("Valid: \(session.inputs.count) recordings, \(session.inputs.reduce(0) { $0 + $1.document.captures.count }) captures")
	}
}
