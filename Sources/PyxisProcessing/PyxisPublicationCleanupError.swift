import Foundation

/// Publication succeeded, but the previous bundle could not be removed from its staging location.
public struct PyxisPublicationCleanupError: Error, CustomStringConvertible, Sendable {
	public let publishedAt: URL
	public let previousBundleAt: URL

	@inlinable
	public init(publishedAt: URL, previousBundleAt: URL) {
		self.publishedAt = publishedAt
		self.previousBundleAt = previousBundleAt
	}

	public var description: String {
		"Published map at \(publishedAt.path); previous bundle remains at \(previousBundleAt.path)"
	}
}
