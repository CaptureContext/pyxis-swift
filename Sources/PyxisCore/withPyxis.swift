/// Overrides Pyxis reads for this operation. It does not apply or undo app side effects.
@discardableResult
public func withPyxis<Result>(
	_ update: (inout PyxisConfiguration) throws -> Void,
	operation: () throws -> Result
) rethrows -> Result {
	var configuration = pyxisConfiguration
	try update(&configuration)
	return try withPyxis(configuration, operation: operation)
}

@discardableResult
public func withPyxis<Result>(
	_ configuration: PyxisConfiguration,
	operation: () throws -> Result
) rethrows -> Result {
	try PyxisContext.$configuration.withValue(configuration, operation: operation)
}

#if compiler(>=6.4)
@discardableResult
public func withPyxis<Result>(
	isolation: isolated (any Actor)? = #isolation,
	_ update: (inout PyxisConfiguration) throws -> Void,
	operation: nonisolated(nonsending) () async throws -> Result
) async rethrows -> Result {
	var configuration = pyxisConfiguration
	try update(&configuration)
	return try await withPyxis(isolation: isolation, configuration, operation: operation)
}

@discardableResult
public func withPyxis<Result>(
	isolation: isolated (any Actor)? = #isolation,
	_ configuration: PyxisConfiguration,
	operation: nonisolated(nonsending) () async throws -> Result
) async rethrows -> Result {
	try await PyxisContext.$configuration.withValue(configuration, operation: operation)
}
#else
@discardableResult
public func withPyxis<Result>(
	isolation: isolated (any Actor)? = #isolation,
	_ update: (inout PyxisConfiguration) throws -> Void,
	operation: () async throws -> Result
) async rethrows -> Result {
	var configuration = pyxisConfiguration
	try update(&configuration)
	return try await withPyxis(isolation: isolation, configuration, operation: operation)
}

@discardableResult
public func withPyxis<Result>(
	isolation: isolated (any Actor)? = #isolation,
	_ configuration: PyxisConfiguration,
	operation: () async throws -> Result
) async rethrows -> Result {
	try await PyxisContext.$configuration.withValue(configuration, operation: operation)
}
#endif
