import Foundation
import PyxisCore

internal func observedDeviceName() -> String? {
	let environment: [String: String] = ProcessInfo.processInfo.environment
	guard
		let actual = environment["SIMULATOR_MODEL_IDENTIFIER"],
		actual == environment[PyxisRecordingEnvironment.Key.deviceModel.rawValue]
	else { return nil }
	return environment[PyxisRecordingEnvironment.Key.deviceName.rawValue]
}
