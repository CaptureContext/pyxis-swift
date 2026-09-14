import Foundation
import PyxisModel

internal func validateRelativeFilePath(_ path: String) throws {
	// The model's asset validator also enforces the shared relative-path alphabet.
	try PyxisValidation.validatePath("assets/" + path)
}

internal func relativeFileURL(path: String, root: URL) throws -> URL {
	guard root.isFileURL else { throw PyxisValidationError("Root must be a file URL") }
	try validateRelativeFilePath(path)
	let resolved: URL = root.standardizedFileURL.resolvingSymlinksInPath()
	let file: URL = resolved.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
	guard file.path.hasPrefix(resolved.path + "/")
	else { throw PyxisValidationError("File escapes its root") }
	return file
}
