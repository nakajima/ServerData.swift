//
//  ModelMacroTest.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ServerDataMacros)
	import ServerDataMacros

	let testMacros: [String: Macro.Type] = [
		"Model": ModelMacro.self,
	]
#endif

#if canImport(ServerDataMacros)
	final class ModelMacroTests: XCTestCase {
		func testMacro() throws {
			assertMacroExpansion(
				"""
				@Model(table: "people") struct Person {
					// We assume this is the primary key since it's named `id`
					// so it gets a PRIMARY KEY AUTO_INCREMENT. Could maybe this
					// configurable at some point…
					var id: Int?

					// Adds a `NOT NULL` to the `age` column
					var age: Int

					// Adds a unique index (courtesy of SQLKit)
					@Column(.unique) var name: String

					// We can store this string as a blob for some reason
					@Column(type: .blob) var about: String?
				}
				""",
				expandedSource: """
				struct Person {
					// We assume this is the primary key since it's named `id`
					// so it gets a PRIMARY KEY AUTO_INCREMENT. Could maybe this
					// configurable at some point…
					var id: Int?

					// Adds a `NOT NULL` to the `age` column
					var age: Int

					// Adds a unique index (courtesy of SQLKit)
					@Column(.unique) var name: String

					// We can store this string as a blob for some reason
					@Column(type: .blob) var about: String?
				}

				extension Person: StorableModel {
					public static let _$table = "people"
					public static var _$columnsByKeyPath: [AnyHashable: ColumnDefinition] {
						[
							\\Person.id: ColumnDefinition(name: "id", sqlType: nil, swiftType: Int.self, isOptional: true, constraints: []),
							\\Person.age: ColumnDefinition(name: "age", sqlType: nil, swiftType: Int.self, isOptional: false, constraints: []),
							\\Person.name: ColumnDefinition(name: "name", sqlType: nil, swiftType: String.self, isOptional: false, constraints: [.unique]),
							\\Person.about: ColumnDefinition(name: "about", sqlType: .blob, swiftType: String.self, isOptional: true, constraints: [])
						]
					}
				}
				""",
				macros: testMacros,
				indentationWidth: .tabs(1)
			)
		}
	}
#else
	final class ModelMacroTests: XCTestCase {
		func testMacro() throws {
			throw XCTSkip("macros are only supported when running tests for the host platform")
		}
	}
#endif
