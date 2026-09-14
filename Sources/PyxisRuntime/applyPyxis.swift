#if canImport(UIKit)
import UIKit
import PyxisCore

/// Applies the prepared configuration to one window without repeating process preparation.
/// Custom adapters override the built-in window adapters for matching keys.
@MainActor
@discardableResult
public func applyPyxis(
	to window: UIWindow,
	configuration: PyxisConfiguration = pyxisConfiguration,
	adapters: [String: PyxisAdapter] = [:]
) throws -> PyxisBootstrapReport? {
	let windowAdapters = pyxisWindowAdapters(window).merging(adapters) { _, custom in custom }
	return try applyPyxisWindowAdapters(configuration: configuration, adapters: windowAdapters)
}
#endif
