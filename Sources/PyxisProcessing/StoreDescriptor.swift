import Foundation

internal struct StoreDescriptor: Codable {
	internal let format: String
	internal let version: Int
	internal let projectID: String

	internal init(format: String = "pyxis.store", version: Int = 1, projectID: String) {
		self.format = format
		self.version = version
		self.projectID = projectID
	}

	private enum CodingKeys: String, CodingKey {
		case format, version
		case projectID = "project_id"
	}
}
