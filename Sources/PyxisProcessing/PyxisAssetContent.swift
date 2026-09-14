import Foundation
import PyxisModel

package struct PyxisAssetContent {
	package var asset: PyxisAsset
	package var bytes: Data

	package init(asset: PyxisAsset, bytes: Data) {
		self.asset = asset
		self.bytes = bytes
	}
}
