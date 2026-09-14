import Foundation
import PyxisModel

public struct PyxisBundleInput: Sendable {
	public var document: PyxisMapDocument
	public var root: URL

	@inlinable
	public init(document: PyxisMapDocument, root: URL) {
		self.document = document
		self.root = root
	}
}
