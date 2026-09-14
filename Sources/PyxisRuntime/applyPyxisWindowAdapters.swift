import PyxisCore

/// Results belong to this application operation; the process report remains unchanged.
@MainActor
internal func applyPyxisWindowAdapters(
	configuration: PyxisConfiguration,
	adapters: [String: PyxisAdapter]
) throws -> PyxisBootstrapReport? {
	guard var report = configuration.report else { return nil }
	try report.validate()

	let requested = configuration.requested.filter { adapters[$0.key] != nil }
	let windowReport = try withPyxis(configuration) {
		try applyPyxisAdapters(requested: requested, adapters: adapters)
	}

	report.variants.merge(windowReport.variants) { _, windowResult in windowResult }
	try report.validate()
	return report
}
