// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "ServerData",
	platforms: [.macOS(.v14)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "ServerData",
			targets: ["ServerData"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/vapor/sql-kit", branch: "main"),
		.package(url: "https://github.com/vapor/mysql-kit", branch: "main"),
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
	],
	targets: [
		.macro(
			name: "ServerDataMacros",
			dependencies: [
				.product(name: "SQLKit", package: "sql-kit"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "ServerData",
			dependencies: [
				"ServerDataMacros",
				.product(name: "SQLKit", package: "sql-kit"),
			]
		),
		.testTarget(
			name: "ServerDataMacrosTests",
			dependencies: [
				"ServerDataMacros",
				.product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
			]
		),
		.testTarget(
			name: "ServerDataTests",
			dependencies: [
				"ServerData",
				.product(name: "MySQLKit", package: "mysql-kit"),
			]
		),
	]
)
