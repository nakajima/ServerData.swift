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
					var id: Int?
					@Column(.unique) var name: String
					var age: Date
					@Column(type: .blob) var about: String?
				}
				""",
				expandedSource: """
				struct Person {
					var id: Int?
					@Column(.unique) var name: String
					var age: Date
					@Column(type: .blob) var about: String?

					public static let _$table = "people"
				}

				extension Person: StorableModel {
					static var _$columnsByKeyPath: [AnyHashable: ColumnDefinition] {
						[
							\\Person.id: ColumnDefinition(name: "id", sqlType: nil, swiftType: Int.self, isOptional: true, constraints: []),
							\\Person.name: ColumnDefinition(name: "name", sqlType: nil, swiftType: String.self, isOptional: false, constraints: [.unique]),
							\\Person.age: ColumnDefinition(name: "age", sqlType: nil, swiftType: Date.self, isOptional: false, constraints: []),
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
