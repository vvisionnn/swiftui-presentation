// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "swiftui-presentation",
	platforms: [.iOS(.v16)],
	products: [
		.library(
			name: "Presentation",
			targets: ["Presentation"]
		),
	],
	targets: [
		.target(
			name: "Presentation",
			dependencies: [
				.target(name: "PresentationShim"),
			]
		),
		.target(name: "PresentationShim"),
		.testTarget(
			name: "PresentationTests",
			dependencies: ["Presentation"]
		),
	]
)
