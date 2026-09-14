import Foundation

/// The lock protects both preparation state and the published configuration.
/// User callbacks always run outside the lock.
package final class PyxisStorage: @unchecked Sendable {
	private let lock: NSLock
	private var configuration: PyxisConfiguration
	private var isPreparing: Bool
	private var isPrepared: Bool

	package init() {
		self.lock = NSLock()
		self.configuration = .init()
		self.isPreparing = false
		self.isPrepared = false
	}

	package var current: PyxisConfiguration {
		self.lock.withLock { self.configuration }
	}

	package func beginPreparation() throws -> PyxisConfiguration {
		try self.lock.withLock {
			guard !self.isPrepared else { throw PyxisBootstrapError.alreadyPrepared }
			guard !self.isPreparing else { throw PyxisBootstrapError.preparationInProgress }
			self.isPreparing = true
			return self.configuration
		}
	}

	package func commit(_ configuration: PyxisConfiguration) {
		self.lock.withLock {
			self.configuration = configuration
			self.isPrepared = true
			self.isPreparing = false
		}
	}

	package func cancelPreparation() {
		self.lock.withLock { self.isPreparing = false }
	}
}
