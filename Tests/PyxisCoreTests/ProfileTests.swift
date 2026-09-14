import Foundation
import PyxisModel
import Testing

@Suite
internal struct ProfileTests {
	@Test
	internal func profileOrderRoundTripsAndDefaultsToZeroWhenOmitted() throws {
		let profile: PyxisProfile = .init(id: "dark", title: "Dark", requested: ["color_scheme": "dark"], order: 3)
		let encoded: Data = try JSONEncoder().encode(profile)
		#expect(try JSONDecoder().decode(PyxisProfile.self, from: encoded) == profile)
		let withoutOrder: Data = Data(#"{"id":"default","title":"Default","requested":{}}"#.utf8)
		#expect(try JSONDecoder().decode(PyxisProfile.self, from: withoutOrder).order == 0)
	}
}
