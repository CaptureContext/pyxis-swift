import Foundation
import PyxisCore
import PyxisModel

/// Edits Xcode's documented xctestrun format without changing the built test bundles.
internal struct RecordingTestRun {
	private let root: [String: Any]
	private let base: [String: Any]
	private let targets: [[String: Any]]

	internal init(data: Data, testRoot: URL) throws {
		guard let original = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
			let metadata = original["__xctestrun_metadata__"] as? [String: Any],
			let version = metadata["FormatVersion"] as? Int,
			[1, 2].contains(version)
		else { throw CLIError.operation("Expected an Xcode xctestrun file with format version 1 or 2.") }
		let root: [String: Any] = original.mapValues { Self.relocate($0, testRoot: testRoot.path) }
		var result: [String: Any] = root
		let base: [String: Any]
		if version == 2 {
			guard let configurations = root["TestConfigurations"] as? [[String: Any]]
			else { throw CLIError.operation("Missing TestConfigurations in xctestrun.") }
			let enabled: [[String: Any]] = configurations.filter { ($0["IsEnabled"] as? Bool) != false }
			guard enabled.count == 1, let configuration = enabled.first
			else { throw CLIError.operation("Use an Xcode test plan with exactly one enabled configuration. Pyxis variants supply the recording configurations.") }
			base = configuration
		} else {
			let targets: [[String: Any]] = root.keys.sorted().compactMap { key in
				guard let target = root[key] as? [String: Any], target["TestBundlePath"] is String else { return nil }
				result.removeValue(forKey: key)
				return target
			}
			base = ["TestTargets": targets]
		}
		guard let targets = base["TestTargets"] as? [[String: Any]], !targets.isEmpty
		else { throw CLIError.operation("No built test targets in xctestrun.") }
		var updatedMetadata: [String: Any] = metadata
		updatedMetadata["FormatVersion"] = 2
		result["__xctestrun_metadata__"] = updatedMetadata
		self.root = result
		self.base = base
		self.targets = targets
	}

	internal func data(
		selections: [RecordingSelection],
		environment: [String: String]
	) throws -> Data {
		var root: [String: Any] = self.root
		root["TestConfigurations"] = try selections.map { selection in
			let recording: PyxisRecordingEnvironment = .init(
				variants: .init(selection.values),
				profileOrder: selection.order
			)
			let values: [String: String] = try environment.merging(recording.encoded()) { _, new in new }
			var configuration: [String: Any] = base
			configuration["Name"] = "Pyxis-\(selection.order + 1)"
			configuration["IsEnabled"] = true
			configuration["TestTargets"] = targets.map { target in
				var target: [String: Any] = target
				target["EnvironmentVariables"] = (target["EnvironmentVariables"] as? [String: String] ?? [:])
					.merging(values) { _, new in new }
				return target
			}
			return configuration
		}
		return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
	}

	internal static func locate(in products: URL, scheme: String, modifiedAfter date: Date? = nil) throws -> URL {
		let files: [URL] = try FileManager.default.contentsOfDirectory(at: products, includingPropertiesForKeys: [.contentModificationDateKey])
		var candidates: [URL] = files.filter {
			$0.pathExtension == "xctestrun" && $0.lastPathComponent.hasPrefix(scheme + "_")
			&& $0.lastPathComponent.contains("iphonesimulator")
		}
		if let date, candidates.count > 1 {
			candidates = try candidates.filter {
				try $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate.map { $0 >= date } == true
			}
		}
		guard candidates.count == 1, let file = candidates.first
		else { throw CLIError.operation("Expected one built iOS simulator xctestrun for \(scheme) in \(products.path). Set xcode.test_run to an explicit file when there are multiple test plans or stale builds.") }
		return file
	}

	private static func relocate(_ value: Any, testRoot: String) -> Any {
		switch value {
		case let string as String:
			return string.replacingOccurrences(of: "__TESTROOT__", with: testRoot)
		case let values as [Any]:
			return values.map { relocate($0, testRoot: testRoot) }
		case let values as [String: Any]:
			return values.mapValues { relocate($0, testRoot: testRoot) }
		default:
			return value
		}
	}
}
