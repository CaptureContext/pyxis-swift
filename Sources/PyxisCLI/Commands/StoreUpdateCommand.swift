import ArgumentParser
import Foundation
import PyxisProcessing

internal struct StoreUpdateCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "update", abstract: "Add a passed recording to a store, retaining unrecorded scopes by default."
	)

	@Argument(help: "Published recording directory, manifest, .pyx or ZIP.")
	internal var input: String

	@OptionGroup
	internal var options: StoreOptions

	@Option(name: .long, help: "merge retains other journey/variant scopes; update replaces this context completely.")
	internal var policy: String = "merge"

	internal init() {}

	internal func validate() throws {
		try requireNonempty(input, name: "input")
		try options.validate()
		guard PyxisStorePolicy(rawValue: policy) != nil
		else { throw ArgumentParser.ValidationError("--policy must be merge or update") }
	}

	internal func run() throws {
		guard let policy = PyxisStorePolicy(rawValue: policy)
		else { throw ArgumentParser.ValidationError("--policy must be merge or update") }
		let session: BundleInputSession = try .init(paths: [input])
		defer { withExtendedLifetime(session) {} }
		let staging: URL = FileManager.default.temporaryDirectory.appendingPathComponent("pyxis-store-input-\(UUID().uuidString)")
		defer {
			// A normalized input is disposable; preserve any original store error.
			try? FileManager.default.removeItem(at: staging)
		}
		var inputs: [PyxisBundleInput] = []
		for (index, input) in session.inputs.enumerated() {
			let destination = staging.appendingPathComponent(String(index))
			inputs.append(try .init(document: BundlePublisher.publish(inputs: [input], to: destination), root: destination))
		}
		let result = try options.store.update(inputs, context: options.context, policy: policy)

		print("Snapshot: \(result.id) [\(options.context)]")
	}
}
