internal enum PyxisContext {
	@TaskLocal
	internal static var configuration: PyxisConfiguration?
}

package let pyxisStorage: PyxisStorage = .init()

/// The current scoped configuration, or the prepared process default.
public var pyxisConfiguration: PyxisConfiguration {
	PyxisContext.configuration ?? pyxisStorage.current
}
