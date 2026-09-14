import Foundation
import Testing
import PyxisCore
import PyxisModel

@Suite
struct RecordingEnvironmentTests {
	@Test
	func runnerValuesRoundTripWithoutUnrelatedEnvironment() throws {
		let expected: PyxisRecordingEnvironment = .init(
			variants: [.colorScheme(.dark), .accessibility(.contentSize(.xxxLarge))],
			profileOrder: 7,
			runID: "shared-run",
			runCreatedAt: Date(timeIntervalSince1970: 1234.5),
			deviceName: "Phone",
			deviceModel: "model"
		)
		var values: [String: String] = try expected.encoded()
		values["UNRELATED"] = "secret"
		let decoded: PyxisRecordingEnvironment = try .init(environment: values)
		#expect(decoded == expected)
		#expect(try decoded.encoded()["UNRELATED"] == nil)
		#expect(try PyxisRecordingEnvironment(environment: [:]) == .init())
		#expect(try PyxisRecordingEnvironment().encoded().isEmpty)
	}

	@Test(arguments: ["-1", "invalid", "9007199254740992"])
	func invalidOrderIsRejected(_ value: String) {
		#expect(throws: PyxisRecordingEnvironmentError.invalidValue(.profileOrder)) {
			try PyxisRecordingEnvironment(environment: [PyxisRecordingEnvironment.Key.profileOrder.rawValue: value])
		}
	}

	@Test(arguments: ["nan", "inf", "invalid"])
	func invalidTimestampIsRejected(_ value: String) {
		#expect(throws: PyxisRecordingEnvironmentError.invalidValue(.runTimestamp)) {
			try PyxisRecordingEnvironment(environment: [PyxisRecordingEnvironment.Key.runTimestamp.rawValue: value])
		}
	}

	@Test
	func malformedVariantsAndInvalidEncodingAreRejected() {
		#expect(throws: (any Error).self) {
			try PyxisRecordingEnvironment(environment: [PyxisRecordingEnvironment.Key.variants.rawValue: "{bad}"])
		}
		#expect(throws: PyxisRecordingEnvironmentError.invalidValue(.profileOrder)) {
			try PyxisRecordingEnvironment(profileOrder: -1).encoded()
		}
	}
}
