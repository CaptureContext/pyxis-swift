// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "pyxis-swift",
	platforms: [.iOS(.v17), .macOS(.v14)],
	products: [
		.library(
			name: "PyxisCore",
			targets: ["PyxisCore"]
		),
		.library(
			name: "PyxisModel",
			targets: ["PyxisModel"],
		),
		.library(
			name: "PyxisProcessing",
			targets: ["PyxisProcessing"],
		),
		.library(
			name: "PyxisRuntime",
			targets: ["PyxisRuntime"],
		),
		.library(
			name: "PyxisXCTest",
			targets: ["PyxisXCTest"],
		),
		.executable(
			name: "pyxis",
			targets: ["pyxis"]
		),
		.plugin(
			name: "PyxisPlugin",
			targets: ["PyxisPlugin"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/swiftlang/swift-subprocess",
			.upToNextMajor(from: "1.0.0")
		),
		.package(
			url: "https://github.com/apple/swift-collections",
			.upToNextMajor(from: "1.6.0")
		),
		.package(
			url: "https://github.com/pointfreeco/swift-custom-dump",
			.upToNextMajor(from: "1.6.1")
		),
		.package(
			url: "https://github.com/weichsel/ZIPFoundation.git",
			.upToNextMinor(from: "0.9.20")
		),
		.package(
			url: "https://github.com/jpsim/Yams.git",
			.upToNextMajor(from: "6.2.2")
		),
		.package(
			url: "https://github.com/capturecontext/swift-async-xcuiautomation",
			.upToNextMinor(from: "0.0.1")
		),
		.package(
			url: "https://github.com/apple/swift-argument-parser",
			.upToNextMajor(from: "1.8.2")
		),
	],

	targets: [
		.target(
			name: "PyxisCore",
			dependencies: [
				.target(
					name: "PyxisModel",
					condition: nil
				),
			]
		),
		.target(
			name: "PyxisModel",
			dependencies: [
				.product(
					name: "OrderedCollections",
					package: "swift-collections"
				),
			]
		),
		.target(
			name: "PyxisProcessing",
			dependencies: [
				.product(
					name: "ZIPFoundation",
					package: "ZIPFoundation"
				),
				.target(
					name: "PyxisModel",
					condition: nil
				),
			]
		),
		.target(
			name: "PyxisRuntime",
			dependencies: [
				.target(
					name: "PyxisCore",
					condition: nil
				),
			]
		),
		.target(
			name: "PyxisXCTest",
			dependencies: [
				.product(
					name: "AsyncXCUIAutomation",
					package: "swift-async-xcuiautomation"
				),
				.target(
					name: "PyxisCore",
					condition: nil
				),
				.target(
					name: "PyxisProcessing",
					condition: nil
				),
			]
		),
		.executableTarget(
			name: "pyxis",
			dependencies: [
				.product(
					name: "Subprocess",
					package: "swift-subprocess",
					condition: .when(platforms: [.macOS])
				),
				.product(
					name: "Yams",
					package: "yams"
				),
				.product(
					name: "ArgumentParser",
					package: "swift-argument-parser"
				),
				.target(
					name: "PyxisProcessing",
					condition: nil
				),
				.target(
					name: "PyxisCore",
					condition: nil
				),
			],
			path: "Sources/PyxisCLI"
		),
		.plugin(
			name: "PyxisPlugin",
			capability: .command(
				intent: .custom(
					verb: "pyxis",
					description: "Run Pyxis capture and bundle tools"
				),
				permissions: [
					.writeToPackageDirectory(
						reason: "Write requested Pyxis capture artifacts"
					),
				]
			),
			dependencies: [
				.target(
					name: "pyxis",
					condition: nil
				),
			]
		),
		.testTarget(
			name: "PyxisCLITests",
			dependencies: [
				.target(
					name: "pyxis",
					condition: nil
				),
			]
		),
		.testTarget(
			name: "PyxisCoreTests",
			dependencies: [
				.product(
					name: "CustomDump",
					package: "swift-custom-dump"
				),
				.target(
					name: "PyxisProcessing",
					condition: nil
				),
			]
		),
		.testTarget(
			name: "PyxisRuntimeTests",
			dependencies: [
				.target(
					name: "PyxisRuntime",
					condition: nil
				),
			]
		),
	]
)
