import Foundation
import PyxisProcessing

internal func writeBundleArchive(
	from input: URL,
	to output: URL
) throws {
	try PyxisArchive().write(loadBundleInput(input.path), to: output)
}
