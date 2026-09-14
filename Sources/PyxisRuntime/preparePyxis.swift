import Foundation
import PyxisCore

/// Installs process-wide configuration once. An absent launch payload is a no-op.
/// Configure typed values before adapters run; adapters can read the staged configuration.
@MainActor
@discardableResult
public func preparePyxis(
	environment: [String: String] = ProcessInfo.processInfo.environment,
	adapters: [String: PyxisAdapter] = [:],
	configure: (inout PyxisConfiguration) throws -> Void = { _ in }
) throws -> PyxisBootstrapReport? {
	try preparePyxis(
		environment: environment,
		adapters: adapters,
		configure: configure,
		storage: pyxisStorage
	)
}

@MainActor
internal func preparePyxis(
	environment: [String: String],
	adapters: [String: PyxisAdapter] = [:],
	configure: (inout PyxisConfiguration) throws -> Void = { _ in },
	storage: PyxisStorage
) throws -> PyxisBootstrapReport? {
	guard let request = try BootstrapRequest.load(environment: environment)
	else { return nil }

	var configuration = try storage.beginPreparation()

	do {
		configuration.requested = request.requested
		try configure(&configuration)
		let report = try withPyxis(configuration) {
			try applyPyxisAdapters(
				requested: request.requested,
				adapters: adapters
			)
		}
		configuration.report = report
		storage.commit(configuration)
		return report
	} catch {
		storage.cancelPreparation()
		throw error
	}
}
