#if DEBUG
import SwiftUI
import PyxisRuntime
import PyxisModel

/// The app owns report transport. Keep the diagnostic out of release builds.
internal struct BootstrapReportView: View {
	private let report: PyxisBootstrapReport

	@Environment(\.colorScheme)
	private var colorScheme

	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	@Environment(\.layoutDirection)
	private var layoutDirection

	internal init(report: PyxisBootstrapReport) {
		self.report = report
	}

	internal var body: some View {
		Text("Pyxis report")
			.font(.system(size: 1))
			.foregroundStyle(.clear)
			.frame(width: 1, height: 1)
			.accessibilityLabel("Pyxis report")
			.accessibilityIdentifier("pyxis.bootstrap.report")
			.accessibilityValue(encodedReport)
			.allowsHitTesting(false)
	}

	private var encodedReport: String {
		var observed: PyxisBootstrapReport = report
		let values: [String: String] = [
			PyxisVariantEntry.colorSchemeKey: colorScheme.pyxisValue.rawValue,
			PyxisVariantEntry.layoutDirectionKey: layoutDirection.pyxisValue.rawValue,
			PyxisVariantEntry.accessibilityContentSizeKey: dynamicTypeSize.variantValue,
		]
		for (key, value) in values where observed.variants[key] != nil {
			observed.variants[key] = .init(status: .observed, value: value)
		}
		do { return try observed.encoded() }
		catch { return "Report encoding failed: \(error)" }
	}

}
#endif
