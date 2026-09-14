import Foundation
import PyxisModel

/// The CLI-to-test-runner contract. Only Pyxis-owned values are read or emitted.
/// Missing fields stay absent, so tests can supply their own manual-run defaults.
public struct PyxisRecordingEnvironment: Equatable, Sendable {
	public var variants: PyxisVariants?
	public var profileOrder: Int?
	public var runID: String?
	public var runCreatedAt: Date?
	public var deviceName: String?
	public var deviceModel: String?

	public init(
		variants: PyxisVariants? = nil,
		profileOrder: Int? = nil,
		runID: String? = nil,
		runCreatedAt: Date? = nil,
		deviceName: String? = nil,
		deviceModel: String? = nil
	) {
		self.variants = variants
		self.profileOrder = profileOrder
		self.runID = runID
		self.runCreatedAt = runCreatedAt
		self.deviceName = deviceName
		self.deviceModel = deviceModel
	}

	public init(environment: [String: String]) throws {
		let variants: PyxisVariants? = try environment[Key.variants.rawValue].map {
			try JSONDecoder().decode(PyxisVariants.self, from: Data($0.utf8))
		}
		let order: Int? = try environment[Key.profileOrder.rawValue].map {
			guard let value = Int($0), value >= 0, value <= 9_007_199_254_740_991
			else { throw PyxisRecordingEnvironmentError.invalidValue(.profileOrder) }
			return value
		}
		let date: Date? = try environment[Key.runTimestamp.rawValue].map {
			guard let seconds = Double($0), seconds.isFinite
			else { throw PyxisRecordingEnvironmentError.invalidValue(.runTimestamp) }
			return Date(timeIntervalSince1970: seconds)
		}
		self.init(
			variants: variants,
			profileOrder: order,
			runID: environment[Key.runID.rawValue],
			runCreatedAt: date,
			deviceName: environment[Key.deviceName.rawValue],
			deviceModel: environment[Key.deviceModel.rawValue]
		)
	}

	/// Encoding validates the same constraints as decoding.
	public func encoded() throws -> [String: String] {
		var values: [String: String] = [:]
		if let variants {
			let encoder: JSONEncoder = .init()
			encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
			values[Key.variants.rawValue] = try String(decoding: encoder.encode(variants), as: UTF8.self)
		}
		values[Key.profileOrder.rawValue] = profileOrder.map(String.init)
		values[Key.runID.rawValue] = runID
		values[Key.runTimestamp.rawValue] = runCreatedAt.map { String($0.timeIntervalSince1970) }
		values[Key.deviceName.rawValue] = deviceName
		values[Key.deviceModel.rawValue] = deviceModel
		_ = try Self(environment: values)
		return values
	}
}
