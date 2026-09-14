import PyxisModel
import Testing
import PyxisCore

@Suite
struct ConfigurationTests {
	private enum NameKey: PyxisConfigurationKey {
		static var defaultValue: String { "default" }
	}

	private enum CapabilityKey: PyxisConfigurationKey {
		static var defaultValue: @Sendable (String) -> String { { $0 } }
	}

	private enum Failure: Error {
		case operation
	}

	@Test
	func configurationCopiesKeepValuesAndCapabilitiesIndependent() async throws {
		var original = PyxisConfiguration()
		#expect(original[NameKey.self] == "default")
		#expect(original[CapabilityKey.self]("input") == "input")
		original[NameKey.self] = "original"
		original[CapabilityKey.self] = { "first: \($0)" }

		var copy = original
		copy[NameKey.self] = "copy"
		copy[CapabilityKey.self] = { "second: \($0)" }
		#expect(original[NameKey.self] == "original")
		#expect(original[CapabilityKey.self]("input") == "first: input")
		#expect(copy[NameKey.self] == "copy")
		#expect(copy[CapabilityKey.self]("input") == "second: input")
	}

	@Test
	func nestedOverridesRestoreAfterSuccessAndFailure() async throws {
		let result: String = withPyxis(PyxisConfiguration()) {
			withPyxis {
				$0[NameKey.self] = "outer"
			} operation: {
				let inner = withPyxis {
					$0[NameKey.self] = "inner"
				} operation: {
					pyxisConfiguration[NameKey.self]
				}
				#expect(inner == "inner")
				#expect(pyxisConfiguration[NameKey.self] == "outer")

				#expect(throws: Failure.self) {
					try withPyxis {
						$0[NameKey.self] = "throwing"
					} operation: {
						throw Failure.operation
					}
				}
				#expect(pyxisConfiguration[NameKey.self] == "outer")
				return pyxisConfiguration[NameKey.self]
			}
		}
		#expect(result == "outer")
		#expect(pyxisConfiguration[NameKey.self] == "default")
	}

	@Test
	func updateFailureDoesNotEnterOperationOrChangeScope() async throws {
		var entered: Bool = false
		#expect(throws: Failure.self) {
			try withPyxis {
				$0[NameKey.self] = "partial"
				throw Failure.operation
			} operation: {
				entered = true
			}
		}
		#expect(!entered)
		#expect(pyxisConfiguration[NameKey.self] == "default")
	}

	@Test
	func propertyWrapperReadsAtAccessTimeWhileSnapshotsRetainScope() async throws {
		@Pyxis(NameKey.self)
		var name: String

		@Pyxis(\.requested)
		var requested: PyxisVariants

		let snapshot = withPyxis {
			$0[NameKey.self] = "captured"
			$0.requested = ["fixture": "demo"]
		} operation: {
			#expect(name == "captured")
			#expect(requested == ["fixture": "demo"])
			return pyxisConfiguration
		}
		#expect(name == "default")
		#expect(snapshot[NameKey.self] == "captured")
		withPyxis(snapshot) {
			#expect(name == "captured")
			#expect(requested == ["fixture": "demo"])
		}
		#expect(name == "default")
	}

	@Test
	func childTasksInheritScopesAndDetachedTasksNeedExplicitSnapshots() async throws {
		await withPyxis {
			$0[NameKey.self] = "parent"
		} operation: {
			let snapshot = pyxisConfiguration
			let inherited = await Task { pyxisConfiguration[NameKey.self] }.value
			let detached = await Task.detached { pyxisConfiguration[NameKey.self] }.value
			let propagated = await Task.detached {
				withPyxis(snapshot) { pyxisConfiguration[NameKey.self] }
			}.value
			#expect(inherited == "parent")
			#expect(detached == "default")
			#expect(propagated == "parent")
		}
		#expect(pyxisConfiguration[NameKey.self] == "default")
	}

	@Test
	func concurrentScopesRemainIsolatedAcrossSuspension() async throws {
		let barrier = ConfigurationScopeBarrier()
		let values = await withTaskGroup(of: String.self, returning: [String].self) { group in
			for value in ["first", "second"] {
				group.addTask {
					await withPyxis {
						$0[NameKey.self] = value
					} operation: {
						await barrier.arrive()
						#expect(pyxisConfiguration[NameKey.self] == value)
						return pyxisConfiguration[NameKey.self]
					}
				}
			}
			var results: [String] = []
			for await value in group { results.append(value) }
			return results
		}
		#expect(values.sorted() == ["first", "second"])
		#expect(pyxisConfiguration[NameKey.self] == "default")
	}

	@Test
	func asyncScopeRestoresAfterThrowingOperation() async throws {
		await #expect(throws: Failure.self) {
			try await withPyxis {
				$0[NameKey.self] = "temporary"
			} operation: {
				await Task.yield()
				#expect(pyxisConfiguration[NameKey.self] == "temporary")
				throw Failure.operation
			}
		}
		#expect(pyxisConfiguration[NameKey.self] == "default")
	}
}
