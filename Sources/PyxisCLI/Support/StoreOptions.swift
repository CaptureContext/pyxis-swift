import ArgumentParser
import Foundation
import PyxisProcessing

internal struct StoreOptions: ParsableArguments {
	@Option(name: .long, help: "Persistent recording-store directory. Can be outside the project.")
	internal var storage: String

	@Option(name: .long, help: "Explicit store context. Git branches are never selected automatically.")
	internal var context: String = "default"

	internal init() {}

	internal func validate() throws {
		try RecordingStorageConfiguration(path: storage, context: context).validate()
	}

	internal var store: PyxisRecordingStore {
		.init(root: URL(fileURLWithPath: storage).standardizedFileURL)
	}
}
