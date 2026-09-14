import Foundation
import PyxisModel
import PyxisProcessing
import Testing

@Suite
struct TimestampTests {
	@Test
	func datesUseISO8601RegardlessOfCoderStrategy() async throws {
		let run = PyxisRunMetadata(id: "run", createdAt: Date(timeIntervalSince1970: 1_767_225_600))
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .secondsSince1970
		let data = try encoder.encode(run)
		let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		#expect(object["created_at"] as? String == "2026-01-01T00:00:00Z")

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .millisecondsSince1970
		#expect(try decoder.decode(PyxisRunMetadata.self, from: data) == run)
	}

	@Test
	func invalidTimestampsFailDuringDecoding() async throws {
		for invalid in [
			"2026-02-30T00:00:00Z", "2026-01-01T24:00:00Z",
			"0000-01-01T00:00:00Z", "2026-01-01T00:00:00+24:00",
			"2026-01-01T00:00:60Z", "2026-01-01T00:00:00",
			"1900-02-29T00:00:00Z", "2026-01-01T00:00:00Z\n",
		] {
			#expect(throws: DecodingError.self) { try decodeRun(invalid) }
		}
		for value: Any in [NSNull(), 1_767_225_600] {
			#expect(throws: DecodingError.self) { try decodeRun(value) }
		}
	}

	@Test
	func fractionalSecondsOffsetsAndGregorianDates() async throws {
		let local = try decodeRun("2024-02-29T12:34:56.123456789+01:00")
		let utc = try decodeRun("2024-02-29T11:34:56.123456789Z")
		#expect(local.createdAt == utc.createdAt)
		#expect(abs(local.createdAt.timeIntervalSince1970 - 1_709_206_496.123456789) < 0.000001)
		#expect(try JSONDecoder().decode(PyxisRunMetadata.self, from: JSONEncoder().encode(local)) == local)

		for (text, seconds) in [
			("0001-01-01T00:00:00Z", -62_135_596_800.0),
			("1582-10-10T00:00:00Z", -12_219_724_800.0),
			("0001-01-01T00:00:00+23:59", -62_135_683_140.0),
			("9999-12-31T23:59:59-23:59", 253_402_387_139.0),
		] {
			let run = try decodeRun(text)
			#expect(run.createdAt.timeIntervalSince1970 == seconds)
			#expect(try JSONDecoder().decode(PyxisRunMetadata.self, from: JSONEncoder().encode(run)) == run)
		}
	}

	@Test
	func optionalObservationDateRejectsNullAndPreservesAbsence() async throws {
		let observation = PyxisObservation(id: "o", journeyID: "j", title: "Tour", testName: "test", profileID: "p")
		let encoder = JSONEncoder()
		var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(observation)) as? [String: Any])
		#expect(object["started_at"] == nil)
		#expect(try JSONDecoder().decode(PyxisObservation.self, from: encoder.encode(observation)).startedAt == nil)

		object["started_at"] = NSNull()
		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(PyxisObservation.self, from: JSONSerialization.data(withJSONObject: object))
		}
		object["started_at"] = "2026-01-01T00:00:01.123456789Z"
		let dated = try JSONDecoder().decode(PyxisObservation.self, from: JSONSerialization.data(withJSONObject: object))
		#expect(try JSONDecoder().decode(PyxisObservation.self, from: encoder.encode(dated)) == dated)
	}

	@Test
	func unrepresentableDatesCannotBeEncodedOrValidated() async throws {
		for seconds in [Double.nan, .infinity, -.infinity, -100_000_000_000, 300_000_000_000] {
			let run = PyxisRunMetadata(id: "r", createdAt: Date(timeIntervalSince1970: seconds))
			#expect(throws: EncodingError.self) { try JSONEncoder().encode(run) }
			let document = PyxisMapDocument(project: .init(id: "p", title: "Project"), run: run)
			#expect(throws: PyxisValidationError.self) { try PyxisValidation.validate(document) }
		}
	}

	@Test
	func mergingComparesTimestampInstants() async throws {
		let first = try PyxisMapDocument(project: .init(id: "p", title: "Project"), run: decodeRun("2026-01-01T01:00:00+01:00"))
		var second = first
		second.run = try decodeRun("2026-01-01T00:00:00Z")
		#expect(try MapMerger.merge([first, second]).run == first.run)
		second.run.createdAt.addTimeInterval(1)
		#expect(throws: PyxisValidationError.self) { try MapMerger.merge([first, second]) }
	}

	private func decodeRun(_ value: Any) throws -> PyxisRunMetadata {
		try JSONDecoder().decode(PyxisRunMetadata.self, from: JSONSerialization.data(withJSONObject: [
			"id": "run", "created_at": value, "provenance": [:],
		]))
	}
}
