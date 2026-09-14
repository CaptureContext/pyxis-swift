import Foundation
import PyxisProcessing

internal struct RecordingStorageConfiguration: Decodable {
	internal let path: String
	internal let context: String
	internal let policy: PyxisStorePolicy

	internal init(path: String, context: String = "default", policy: PyxisStorePolicy = .merge) {
		self.path = path
		self.context = context
		self.policy = policy
	}

	internal init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		try self.init(
			path: container.decode(String.self, forKey: .path),
			context: container.contains(.context) ? container.decode(String.self, forKey: .context) : "default",
			policy: container.contains(.policy) ? container.decode(PyxisStorePolicy.self, forKey: .policy) : .merge
		)
	}

	internal func validate() throws {
		try requireNonempty(path, name: "storage.path")
		try requireNonempty(context, name: "storage.context")
		guard context.range(of: "^[A-Za-z0-9._-]{1,128}$", options: .regularExpression) != nil,
			context != ".", context != ".."
		else { throw CLIError.operation("storage.context must be one ASCII-safe name") }
	}

	private enum CodingKeys: String, CodingKey {
		case path, context, policy
	}
}
