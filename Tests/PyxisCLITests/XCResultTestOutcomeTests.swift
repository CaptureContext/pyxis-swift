import Foundation
import Testing
@testable import pyxis

@Suite
struct XCResultTestOutcomeTests {
	@Test
	func promotionRequiresCompletionAndEveryNativeExecutionToPass() async throws {
		let passed = XCResultTestOutcome(testResult: "Passed", testRuns: [.init(nodeType: "Test Case Run", result: "Passed")])
		#expect(passed.status(completed: true) == .passed)
		#expect(passed.status(completed: false) == .incomplete)
		let native = XCResultTestOutcome(testResult: "Passed", testRuns: [
			.init(nodeType: "Device", result: "Passed", children: [.init(nodeType: "Test Plan Configuration", result: "Passed")]),
		])
		#expect(native.status(completed: true) == .passed)
		let parameterized = XCResultTestOutcome(testResult: "Passed", testRuns: [
			.init(nodeType: "Arguments", result: "Passed", children: [.init(nodeType: "Test Value")]),
			.init(nodeType: "Arguments", result: "Passed", children: [.init(nodeType: "Test Value")]),
		])
		#expect(parameterized.status(completed: true) == .passed)
		let retry = XCResultTestOutcome(testResult: "Passed", testRuns: [
			.init(nodeType: "Repetition", children: [.init(nodeType: "Test Case Run", result: "Failed")]),
			.init(nodeType: "Repetition", children: [.init(nodeType: "Test Case Run", result: "Passed")]),
		])
		#expect(retry.status(completed: true) == .failed)
		#expect(XCResultTestOutcome(testResult: "Passed", testRuns: []).status(completed: true) == .incomplete)
		#expect(XCResultTestOutcome(testResult: "Skipped", testRuns: []).status(completed: true) == .incomplete)
	}
}
