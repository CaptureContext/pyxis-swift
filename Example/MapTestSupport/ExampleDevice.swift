import Foundation

internal enum ExampleDevice: String, CaseIterable, Sendable {
	case iPhone18Pro = "iPhone 18 Pro"
	case iPhoneSE2 = "iPhone SE 2"

	internal var modelIdentifier: String {
		switch self {
		case .iPhone18Pro: "iPhone19,2"
		case .iPhoneSE2: "iPhone12,8"
		}
	}

	internal static var simulatorModel: String? {
		ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
	}

	internal static func name(for model: String) -> String {
		allCases.first { $0.modelIdentifier == model }?.rawValue ?? model
	}
}
