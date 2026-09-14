import Foundation
import PyxisModel

internal struct PublicationAsset {
	internal let asset: PyxisAsset
	internal let root: URL
	internal let source: URL
	internal let documentIndex: Int
	internal let captureIndex: Int

	internal init(asset: PyxisAsset, root: URL, source: URL, documentIndex: Int, captureIndex: Int) {
		self.asset = asset
		self.root = root
		self.source = source
		self.documentIndex = documentIndex
		self.captureIndex = captureIndex
	}
}
