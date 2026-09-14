import Foundation
import PyxisModel

public struct PyxisBootstrapReport: Codable, Equatable, Sendable {
	public var variants: [String: PyxisVariantResult]

	public init(variants: [String: PyxisVariantResult]) {
		self.variants = variants
	}

	public init(encoded string: String) throws {
		let report = try JSONDecoder().decode(Self.self, from: Data(string.utf8))
		try report.validate()
		self.init(variants: report.variants)
	}

	public func encoded() throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return try String(decoding: encoder.encode(self), as: UTF8.self)
	}

	package func validate() throws {
		for (key, result) in self.variants {
			switch result.status {
			case .applied, .observed:
				if result.value == nil { throw PyxisBootstrapError.invalidReport(key) }
			case .unsupported, .unverified:
				if result.reason == nil { throw PyxisBootstrapError.invalidReport(key) }
			}
		}
	}

	public func covering(_ requested: PyxisVariants) -> Self {
		var variants = self.variants

		for key in requested.keys where variants[key] == nil {
			variants[key] = .init(
				status: .unverified,
				reason: "No report was supplied for this request."
			)
		}

		return .init(variants: variants)
	}
}
