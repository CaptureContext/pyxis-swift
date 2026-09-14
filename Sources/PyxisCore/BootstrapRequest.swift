import PyxisModel

import Foundation

package struct BootstrapRequest: Codable, Equatable, Sendable {
	package var version: Int
	package var requested: PyxisVariants

	package init(
		version: Int = 1,
		requested: PyxisVariants
	) {
		self.version = version
		self.requested = requested
	}

	package static func load(environment: [String: String]) throws -> Self? {
		guard let payload = environment[pyxisEnvironmentKey]
		else { return nil }

		let request = try JSONDecoder().decode(
			Self.self,
			from: Data(payload.utf8)
		)

		guard request.version == 1
		else { throw PyxisBootstrapError.unsupportedVersion(request.version) }

		return request
	}

	package func encoded() throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return try String(
			decoding: encoder.encode(self),
			as: UTF8.self
		)
	}
}
