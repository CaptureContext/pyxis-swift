import Darwin
import Foundation
import Testing
@testable import pyxis

@Suite
struct ProcessExecutionTests {
	@Test
	func argumentsEnvironmentAndWorkingDirectoryRemainLiteral() async throws {
		let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
		let output = try await processOutput(
			"/bin/sh", ["-c", "printf '%s\\n%s\\n' \"$1\" \"$PYXIS_TEST_VALUE\"; pwd", "sh", "$(literal) with spaces"],
			environment: ["PYXIS_TEST_VALUE": "custom value"], directory: directory
		)
		let lines = output.split(separator: "\n").map(String.init)
		#expect(Array(lines.prefix(2)) == ["$(literal) with spaces", "custom value"])
		let reportedDirectory = try #require(lines.last)
		#expect(URL(fileURLWithPath: reportedDirectory).resolvingSymlinksInPath().path == directory.path)
		#expect(try await runProcess("/bin/sh", ["-c", "exit 17"]) == 17)
		await #expect(throws: (any Error).self) { try await processOutput("/bin/sh", ["-c", "exit 17"]) }
	}

	@Test
	func outputIsNotTruncatedAndLogsIncludeBothStreams() async throws {
		let output = try await processOutput("/usr/bin/head", ["-c", "262144", "/dev/zero"])
		#expect(output.utf8.count == 262144)
		let log = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: log) }
		#expect(try await runProcess("/bin/sh", ["-c", "printf stdout; printf stderr >&2"], log: log) == 0)
		#expect(try String(contentsOf: log, encoding: .utf8) == "stdoutstderr")
	}

	@Test(.timeLimit(.minutes(1)))
	func cancellingExecutionReapsTheChildProcess() async throws {
		let ready = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: ready) }
		let task = Task {
			try await runProcess("/bin/sh", ["-c", "echo $$ > \"$1\"; exec /bin/sleep 30", "sh", ready.path])
		}
		defer { task.cancel() }
		let deadline = ContinuousClock.now.advanced(by: .seconds(10))
		while !FileManager.default.fileExists(atPath: ready.path), ContinuousClock.now < deadline {
			try await Task.sleep(for: .milliseconds(10))
		}
		let pid = try #require(Int32(String(contentsOf: ready, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)))
		task.cancel()
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(kill(pid, 0) == -1)
		#expect(errno == ESRCH)
	}
}
