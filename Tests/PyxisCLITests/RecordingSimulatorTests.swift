import Foundation
import os
import Testing
@testable import pyxis

@Suite
struct RecordingSimulatorTests {
	@Test(arguments: [true, false])
	func temporarySimulatorIsDeletedWhenBootOrTestsFail(bootFails: Bool) async throws {
		let calls = OSAllocatedUnfairLock(initialState: [[String]]())
		let identifier = UUID().uuidString
		let tools = RecordingTools(
			execute: { arguments, _, _ in
				calls.withLock { $0.append(arguments) }
				return arguments == ["simctl", "boot", identifier] && bootFails ? 1 : 0
			},
			output: { arguments in
				calls.withLock { $0.append(arguments) }
				return identifier + "\n"
			}
		)
		let simulator = RecordingSimulator(
			destination: .init(name: "Phone", deviceType: "phone", model: "Phone1,1", runtime: "ios", osVersion: "27"),
			tools: tools
		)
		await #expect(throws: (any Error).self) {
			try await simulator.withDevice(name: "Pyxis test", logDirectory: URL(fileURLWithPath: "/unused")) { _ in
				throw CLIError.operation("Tests failed")
			}
		}
		#expect(calls.withLock { $0.last } == ["simctl", "delete", identifier])
		#expect(calls.withLock { $0.filter { $0.contains("delete") }.count } == 1)
	}

	@Test
	func cleanupFailureDoesNotReportSuccessfulRecording() async throws {
		let identifier = UUID().uuidString
		let tools = RecordingTools(
			execute: { arguments, _, _ in arguments.contains("delete") ? 1 : 0 },
			output: { _ in identifier }
		)
		let simulator = RecordingSimulator(
			destination: .init(name: "Phone", deviceType: "phone", model: "Phone1,1", runtime: "ios", osVersion: "27"),
			tools: tools
		)
		await #expect(throws: (any Error).self) {
			try await simulator.withDevice(name: "Pyxis test", logDirectory: URL(fileURLWithPath: "/unused")) { _ in 42 }
		}
	}
	@Test(arguments: [true, false])
	func cancellationStillDeletesTheTemporarySimulator(duringCreation: Bool) async throws {
		let calls = OSAllocatedUnfairLock(initialState: [[String]]())
		let identifier = UUID().uuidString
		let (events, ready) = AsyncStream<Void>.makeStream()
		let (release, proceed) = AsyncStream<Void>.makeStream()
		let tools = RecordingTools(
			execute: { arguments, _, _ in
				calls.withLock { $0.append(arguments) }
				try Task.checkCancellation()
				return 0
			},
			output: { _ in
				if duringCreation {
					ready.yield(())
					for await _ in release { break }
				}
				return identifier
			}
		)
		let simulator = RecordingSimulator(
			destination: .init(name: "Phone", deviceType: "phone", model: "Phone1,1", runtime: "ios", osVersion: "27"),
			tools: tools
		)
		let task = Task {
			try await simulator.withDevice(name: "Pyxis test", logDirectory: URL(fileURLWithPath: "/unused")) { _ in
				ready.yield(())
				try await Task.sleep(for: .seconds(30))
			}
		}
		for await _ in events { break }
		task.cancel()
		proceed.yield(())
		await #expect(throws: CancellationError.self) { try await task.value }
		let recorded = calls.withLock { $0 }
		#expect(recorded.last == ["simctl", "delete", identifier])
		#expect(recorded.filter { $0.contains("delete") }.count == 1)
		if duringCreation { #expect(!recorded.contains { $0.contains("boot") }) }
	}

}
