import ArgumentParser
import Foundation

internal struct DemoCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "demo",
		abstract: "Generate a synthetic example without running a simulator."
	)

	@Option(
		name: .long,
		help: "Directory for the generated synthetic bundle."
	)
	internal var output: String

	internal init() {}

	internal func validate() throws {
		try requireNonempty(self.output, name: "--output")
	}

	internal func run() throws {
		try generateDemo(to: URL(fileURLWithPath: self.output))
	}
}
