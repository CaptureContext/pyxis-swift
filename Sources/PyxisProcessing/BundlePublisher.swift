import Foundation
import PyxisModel

public enum BundlePublisher {
	/// Validate every input before publishing output. An existing valid bundle is atomically swapped.
	public static func publish(inputs: [PyxisBundleInput], to output: URL) throws -> PyxisMapDocument {
		let publication: BundlePublication = try .init(inputs: inputs, to: output)
		do {
			while let work = try publication.nextAsset() {
				try autoreleasepool {
					try publication.write(
						.init(asset: work.asset, bytes: BundleValidator.assetData(work.asset, root: work.root)),
						for: work
					)
				}
			}
			return try publication.commit()
		} catch { try publication.fail(error) }
	}

	/// Async transforms share the same validation, staging and atomic commit as ordinary publication.
	nonisolated(nonsending)
	package static func publish(
		inputs: [PyxisBundleInput],
		to output: URL,
		transformAsset: (PyxisAsset, Data) async throws -> PyxisAssetContent
	) async throws -> PyxisMapDocument {
		let publication: BundlePublication = try .init(inputs: inputs, to: output)
		do {
			while let work = try publication.nextAsset() {
				try Task.checkCancellation()
				let bytes: Data = try autoreleasepool { try BundleValidator.assetData(work.asset, root: work.root) }
				let content: PyxisAssetContent = try await transformAsset(work.asset, bytes)
				try autoreleasepool { try publication.write(content, for: work) }
			}
			try Task.checkCancellation()
			return try publication.commit()
		} catch { try publication.fail(error) }
	}
}
