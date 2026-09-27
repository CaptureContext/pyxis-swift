// swift-tools-version: 6.2

import PackageDescription

let package = Package(
	name: "pyxis-example",
	platforms: [.iOS(.v17)],
	products: [
		.library(
			name: "ExampleSnapshotTesting",
			targets: ["ExampleSnapshotTesting"]
		),
		.library(
			name: "ExampleApp",
			// Keep the app implementation in the host so hosted tests reuse its runtime.
			type: .static,
			targets: ["ExampleApp"]
		),
		.library(
			name: "ExampleTesting",
			targets: ["ExampleTesting"]
		),
	],
	dependencies: [
		.package(path: ".."),
	],
	targets: [
		.target(
			name: "ExampleSnapshotTesting",
			dependencies: [
				.product(name: "PyxisTesting", package: "pyxis-swift"),
			]
		),
		.target(
			name: "ExampleApp",
			dependencies: [
				.product(
					name: "PyxisRuntime",
					package: "pyxis-swift"
				),
			],
			exclude: ["README.md"]
		),
		.target(
			name: "ExampleTesting",
			dependencies: [
				.product(
					name: "PyxisXCTest",
					package: "pyxis-swift"
				),
			],
			exclude: ["README.md"]
		),
	]
)
