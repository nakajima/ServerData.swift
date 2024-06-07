//
//  SQLPredicateMacroTest.swift
//
//
//  Created by Pat Nakajima on 5/19/24.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(ServerDataMacros)
	import ServerDataMacros

	let testSQLPredicateMacros: [String: Macro.Type] = [
		"SQL": SQLMacro.self,
	]
#endif

#if canImport(ServerDataMacros)
	final class SQLPredicateMacroTests: XCTestCase {
		func testContains() throws {
			assertMacroExpansion(
				"""
				#SQL<Person> {
					ids.contains($0.id ?? -1)
				}
				""",
				expandedSource: """
				SQLPredicate(expression:
					SQLPredicateExpressions.SQLPredicateBinaryExpression(
						SQLPredicateExpressions.Coalesce(SQLPredicateExpressions.Column("id"), SQLPredicateExpressions.Value(-1)),
						.in,
						SQLPredicateExpressions.Value(ids)
					)
				)
				""",
				macros: testSQLPredicateMacros,
				indentationWidth: .tabs(1)
			)
		}

		func testMacro() throws {
			assertMacroExpansion(
				"""
				#SQL<Person> {
					$0.id == 123 && $0.name != "Pat" || ($0.age! > year!) && ($0.id ?? -1) > 0 || [1,2,3].contains($0.id)
				}
				""",
				expandedSource: """
				SQLPredicate(expression:
					SQLPredicateExpressions.SQLPredicateBinaryExpression(
						SQLPredicateExpressions.SQLPredicateBinaryExpression(
							SQLPredicateExpressions.SQLPredicateBinaryExpression(
								SQLPredicateExpressions.SQLPredicateBinaryExpression(
									SQLPredicateExpressions.Column("id"),
									.equal,
									SQLPredicateExpressions.Value(123)
								),
								.and,
								SQLPredicateExpressions.SQLPredicateBinaryExpression(
									SQLPredicateExpressions.Column("name"),
									.notEqual,
									SQLPredicateExpressions.Value("Pat")
								)
							),
							.or,
							SQLPredicateExpressions.SQLPredicateBinaryExpression(
								SQLPredicateExpressions.SQLPredicateBinaryExpression(
									SQLPredicateExpressions.Column("age"),
									.greaterThan,
									SQLPredicateExpressions.Value(year!)
								),
								.and,
								SQLPredicateExpressions.SQLPredicateBinaryExpression(
									SQLPredicateExpressions.Coalesce(SQLPredicateExpressions.Column("id"), SQLPredicateExpressions.Value(-1)),
									.greaterThan,
									SQLPredicateExpressions.Value(0)
								)
							)
						),
						.or,
						SQLPredicateExpressions.SQLPredicateBinaryExpression(
							SQLPredicateExpressions.Column("id"),
							.in,
							[SQLPredicateExpressions.Value(1), SQLPredicateExpressions.Value(2), SQLPredicateExpressions.Value(3)]
						)
					)
				)
				""",
				macros: testSQLPredicateMacros,
				indentationWidth: .tabs(1)
			)
		}
	}
#endif
