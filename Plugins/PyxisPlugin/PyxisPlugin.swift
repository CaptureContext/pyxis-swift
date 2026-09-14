import Foundation
import PackagePlugin

@main
internal struct PyxisPlugin: CommandPlugin {
	internal func performCommand(
		context: PluginContext,
		arguments: [String]
	) async throws {
		let tool = try context.tool(named: "pyxis")

		let process = Process()
		process.executableURL = tool.url
		process.arguments = arguments
		process.currentDirectoryURL = context.package.directoryURL

		try process.run()
		process.waitUntilExit()

		guard process.terminationStatus == 0 else {
			Diagnostics.error(
				"""
				Pyxis exited with status \(process.terminationStatus). \
				Use the standalone CLI if simulator access is blocked by the plugin sandbox.
				"""
			)
			throw PluginFailure.commandFailed
		}
	}
}
