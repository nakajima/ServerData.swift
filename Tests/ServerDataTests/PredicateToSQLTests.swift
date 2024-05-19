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
@Model(table: "predicateToSQLModel") struct PredicateToSQLModel {
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
			#Predicate { $0.name == "Pat" },
			"`name` = ?", ["Pat"]
		)
	}

	func testNonEquality() {
		test(
			line: #line,
			#Predicate { $0.name != "Pat" },
			"`name` <> ?", ["Pat"]
		)
	}

	func testCompound() {
		test(
			line: #line,
			#Predicate { $0.name == "Pat" && $0.name != "Not Pat" },
			"`name` = ? AND `name` <> ?", ["Pat", "Not Pat"]
		)
	}

	func testCompare() {
		test(
			line: #line,
			#Predicate { ($0.id ?? -1) > 0 },
			"COALESCE(`id`, ?) > ?", [-1, 0]
		)
	}

	func testOr() {
		test(
			line: #line,
			#Predicate { $0.name == "Pat" || $0.name == "Not Pat" },
			"`name` = ? OR `name` = ?", ["Pat", "Not Pat"]
		)
	}

	func testTestNested() {
		test(
			line: #line,
			#Predicate { $0.age > 30 && ($0.name == "Pat" || $0.name == "Not Pat") },
			"`age` > ? AND `name` = ? OR `name` = ?", [30, "Pat", "Not Pat"]
		)
	}

	func testForceUnwrapColumn() {
		test(
			line: #line,
			#Predicate { $0.id! > 30 },
			"`id` > ?", [30]
		)
	}

	func testForceUnwrapValue() {
		let age: Int? = 30

		test(
			line: #line,
			#Predicate { $0.age > age! },
			"`age` > ?", [30]
		)
	}

	func test(line: UInt, _ predicate: Predicate<PredicateToSQLModel>, _ expr2: SQLBinaryExpression) {
		let expr1 = PredicateToSQL(predicate: predicate).expressions()!

		let (sql1, binds1) = database.serialize(expr1)
		let (sql2, binds2) = database.serialize(expr2)

		XCTAssertEqual(sql1, sql2, line: line)
		XCTAssertEqual(binds1.debugDescription, binds2.debugDescription, line: line)
	}

	func test(line: UInt, _ predicate: Predicate<PredicateToSQLModel>, _ sql: String, _ binds: [Any]) {
		let expr1 = PredicateToSQL(predicate: predicate).expressions()!

		let (sql1, binds1) = database.serialize(expr1)

		let sql = dialectize(sql: sql)

		XCTAssertEqual(sql1, sql, line: line)
		XCTAssertEqual(binds1.debugDescription, binds.debugDescription, line: line)
	}

	// I wrote the tests with MySQL syntax so this function is sort of a hack to try to make
	// sure they work in whatever dialect
	func dialectize(sql: String) -> String {
		var i = 0
		return sql.replacing(#/\?/#) { match in
			i += 1
			return database.serialize(database.dialect.bindPlaceholder(at: i)).sql
		}
		.replacing("`", with: database.serialize(database.dialect.identifierQuote).sql)
	}
}
