import PyxisCore
import PyxisModel

@MainActor
internal func applyPyxisAdapters(
	requested: PyxisVariants,
	adapters: [String: PyxisAdapter]
) throws -> PyxisBootstrapReport {
	var results: [String: PyxisVariantResult] = [:]
	for key in requested.keys.sorted() {
		guard let value = requested[key] else { continue }
		guard let adapter = adapters[key] else {
			results[key] = .init(
				status: key == "accessibility.color_filters" ? .unsupported : .unverified,
				reason: key == "accessibility.color_filters"
				? "Color filters have no verified screenshot implementation."
				: "The app has no adapter for this request."
			)
			continue
		}

		do {
			results[key] = try adapter(value)
		} catch {
			results[key] = .init(
				status: .unverified,
				reason: "Adapter failed: \(error)"
			)
		}
	}
	let report = PyxisBootstrapReport(variants: results)
	try report.validate()
	return report
}
