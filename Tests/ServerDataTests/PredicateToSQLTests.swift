//
//  PredicateToSQLTests.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
@testable import ServerData
import SQLKit
import XCTest

// Not worrying about actually creating an underlying DB for this
// since all we care about is the struct conforming to StorableModel.
@Model(table: "predicateToSQLModel") struct PredicateToSQLModel: Sendable {
	var id: Int?
	var name: String
	var age: Int
}

class PredicateToSQLTests: XCTestCase {
	var database: (any SQLDatabase)!

	override func setUp() async throws {
		database = await Container.test().database
	}

	func testBasicEquality() {
		test(
			line: #line,
			#SQL { $0.name == "Pat" },
			"`name` = ?", ["Pat"]
		)
	}

	func testBasicColumns() {
		test(
			line: #line,
			#SQL { $0.name == $0.name },
			"`name` = `name`", []
		)
	}

	func testBasicNumbers() {
		test(
			line: #line,
			#SQL { _ in 1 == 1 },
			"? = ?", [1, 1]
		)
	}

	func testNonEquality() {
		test(
			line: #line,
			#SQL { $0.name != "Pat" },
			"`name` <> ?", ["Pat"]
		)
	}

	func testCompound() {
		test(
			line: #line,
			#SQL { $0.name == "Pat" && $0.name != "Not Pat" },
			"`name` = ? AND `name` <> ?", ["Pat", "Not Pat"]
		)
	}

	func testCompare() {
		test(
			line: #line,
			#SQL { ($0.id ?? -1) > 0 },
			"COALESCE(`id`, ?) > ?", [-1, 0]
		)
	}

	func testOr() {
		test(
			line: #line,
			#SQL { $0.name == "Pat" || $0.name == "Not Pat" },
			"`name` = ? OR `name` = ?", ["Pat", "Not Pat"]
		)
	}

	func testTestNested() {
		test(
			line: #line,
			#SQL { $0.age > 30 && ($0.name == "Pat" || $0.name == "Not Pat") },
			"`age` > ? AND `name` = ? OR `name` = ?", [30, "Pat", "Not Pat"]
		)
	}

	func testForceUnwrapColumn() {
		test(
			line: #line,
			#SQL { $0.id! > 30 },
			"`id` > ?", [30]
		)
	}

	func testForceUnwrapValue() {
		let age: Int? = 30

		test(
			line: #line,
			#SQL { $0.age > age! },
			"`age` > ?", [30]
		)
	}

	func testContains() {
		let ids = [1, 2, 3]

		test(
			line: #line,
			#SQL { ids.contains($0.id!) },
			"`id` IN ?", [ids]
		)
	}

	func test(line: UInt, _ predicate: SQLPredicate<PredicateToSQLModel>, _ expectedSQL: String, _ expectedBinds: [Any]) {
		let expr1 = predicate.expression()

		let (generatedSQL, generatedBinds) = database.serialize(expr1)

		let sql = dialectize(sql: expectedSQL)

		XCTAssertEqual(generatedSQL, sql, line: line)
		XCTAssertEqual(generatedBinds.debugDescription, expectedBinds.debugDescription, line: line)
	}

	// I wrote the tests with MySQL syntax so this function is sort of a hack to try to make
	// sure they work in whatever dialect
	func dialectize(sql: String) -> String {
		var i = 0
		return sql.replacing(#/\?/#) { _ in
			i += 1
			return database.serialize(database.dialect.bindPlaceholder(at: i)).sql
		}
		.replacing("`", with: database.serialize(database.dialect.identifierQuote).sql)
	}
}
