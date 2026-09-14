import Foundation
import PyxisModel
import Testing

@Suite
struct WireFormatTests {
	@Test
	func plainCodableUsesExplicitSnakeCaseKeysAndPreservesOpaqueValues() async throws {
		let document = sampleDocument()
		let data = try JSONEncoder().encode(document)
		let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		let run = try #require(json["run"] as? [String: Any])
		let state = try #require((json["states"] as? [[String: Any]])?.first)
		let observation = try #require((json["observations"] as? [[String: Any]])?.first)
		let capture = try #require((json["captures"] as? [[String: Any]])?.first)
		let asset = try #require(capture["asset"] as? [String: Any])
		let transition = try #require((json["transitions"] as? [[String: Any]])?.first)

		#expect(Set(run.keys) == ["id", "created_at", "provenance"])
		#expect(Set(state.keys) == ["id", "screen_id", "domain_id", "title", "label", "order", "metadata"])
		#expect(Set(observation.keys) == ["id", "journey_id", "title", "test_name", "profile_id", "status", "variants", "started_at", "failure"])
		#expect(Set(capture.keys) == ["id", "state_id", "observation_id", "sequence", "asset"])
		#expect(Set(asset.keys) == ["path", "sha256", "media_type", "width", "height"])
		#expect(Set(transition.keys) == ["id", "observation_id", "from_state_id", "to_state_id", "action", "kind", "sequence", "status", "failure"])
		#expect(json["format"] as? String == "pyxis.map")
		#expect(asset["media_type"] as? String == "image/png")

		let decoded = try JSONDecoder().decode(PyxisMapDocument.self, from: data)
		#expect(decoded == document)
		#expect(Data(decoded.states[0].id.utf8) == Data(document.states[0].id.utf8))
		#expect(decoded.states[0].metadata["screenID"] == "KeepThisID")
		#expect(decoded.run.provenance["testName"] == "CustomSDKValue")
		#expect(decoded.profiles[0].requested["custom.HelloWorld"] == "CamelCaseValue")
		#expect(decoded.profiles[0].requested["device"] == "iPhone16,1")
		#expect(decoded.profiles[0].requested["locale"] == "en_US")
		#expect(decoded.profiles[0].requested["time_zone"] == "Europe/Warsaw")
		#expect(decoded.profiles[0].requested["accessibility.content_size"] == "accessibility_xxx_large")
		#expect(decoded.transitions[0].kind == "custom.PushRoute")
		#expect(try PyxisJSON.decode(PyxisJSON.encode(document)) == document)
	}

	@Test
	func unknownFieldsDoNotChangeDecodedRecords() async throws {
		let document = sampleDocument()
		let data = try JSONEncoder().encode(document)
		var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
		json["future_field"] = ["someKey": "SomeValue"]
		var run = try #require(json["run"] as? [String: Any])
		run["future_field"] = "Additional information"
		json["run"] = run
		let expanded = try JSONSerialization.data(withJSONObject: json)
		#expect(try JSONDecoder().decode(PyxisMapDocument.self, from: expanded) == document)
		#expect(try PyxisJSON.decode(expanded) == document)
	}

	private func sampleDocument() -> PyxisMapDocument {
		let state = PyxisState(
			id: "Home.e\u{301}.ReadyID",
			screenID: "HomeScreenID",
			domainID: "MyDomain",
			title: "My Home",
			metadata: ["screenID": "KeepThisID", "mediaType": "image/CustomXML"]
		)
		let profile = PyxisProfile(
			id: "MyProfile",
			title: "Custom Profile",
			requested: [
				"accessibility.content_size": "accessibility_xxx_large",
				"custom.HelloWorld": "CamelCaseValue",
				"device": "iPhone16,1",
				"locale": "en_US",
				"time_zone": "Europe/Warsaw",
			]
		)
		return PyxisMapDocument(
			project: .init(id: "Project.HTTPClientV2", title: "My Custom App"),
			run: .init(id: "MyRunID", createdAt: Date(timeIntervalSince1970: 1_767_225_600), provenance: ["testName": "CustomSDKValue"]),
			domains: [.init(id: "MyDomain", title: "Main")],
			states: [state],
			profiles: [profile],
			observations: [.init(
				id: "MyObservation",
				journeyID: "MyJourney",
				title: "Walk Through",
				testName: "testWriteANote",
				profileID: profile.id,
				status: .failed,
				variants: profile.requested.mapValues { .init(status: .applied, value: $0) },
				startedAt: Date(timeIntervalSince1970: 1_767_225_601),
				failure: "ExpectedEdgeFailure"
			)],
			captures: [.init(
				id: "MyCapture", stateID: state.id, observationID: "MyObservation", sequence: 0,
				asset: .init(path: "assets/MyCapture.png", sha256: String(repeating: "a", count: 64), width: 2, height: 2)
			)],
			transitions: [.init(
				id: "MyTransition", observationID: "MyObservation", fromStateID: state.id, toStateID: state.id,
				action: "TryAgain", kind: "custom.PushRoute", sequence: 1, status: .failed, failure: "StopHere"
			)]
		)
	}
}
