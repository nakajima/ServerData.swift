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

@Model(table: "predicateToSQLModel") struct PredicateToSQLModel {
	var id: Int?
	var name: String
}

class PredicateToSQLTests: XCTestCase {
	var database: (any SQLDatabase)!

	override func setUp() async throws {
		database = await Container.test().database
	}

	func test(line: UInt, _ predicate: Predicate<PredicateToSQLModel>, _ expr2: SQLBinaryExpression) {
		let expr1 = PredicateToSQL(predicate: predicate).expressions()!

		let (sql1, binds1) = database.serialize(expr1)
		let (sql2, binds2) = database.serialize(expr2)

		XCTAssertEqual(sql1, sql2, line: line)
		XCTAssertEqual(binds1.debugDescription, binds2.debugDescription, line: line)
	}

	func testBasicEquality() {
		test(line: #line,
		     #SQLPredicate { $0.name == "Pat" },
		     SQLBinaryExpression(SQLColumn("name"), .equal, SQLBind("Pat")))
	}

	func testNonEquality() {
		test(line: #line,
		     #Predicate { $0.name != "Pat" },
		     SQLBinaryExpression(SQLColumn("name"), .notEqual, SQLBind("Pat")))
	}

	func testCompound() {
		test(line: #line,
		     #Predicate { $0.name == "Pat" && $0.name != "Not Pat" },
		     SQLBinaryExpression(
		     	SQLBinaryExpression(SQLColumn("name"), .equal, SQLBind("Pat")),
		     	.and,
		     	SQLBinaryExpression(SQLColumn("name"), .notEqual, SQLBind("Not Pat"))
		     ))
	}

	func testCompare() {
		test(line: #line,
		     #Predicate { ($0.id ?? -1) > 0 },
		     SQLBinaryExpression(SQLFunction.coalesce(SQLColumn("id"), SQLBind(-1)), .greaterThan, SQLBind(0)))
	}

	func testOr() {
		test(line: #line,
		     #Predicate { $0.name == "Pat" || $0.name == "Not Pat" },
		     .init(
		     	SQLBinaryExpression(SQLColumn("name"), .equal, SQLBind("Pat")),
		     	.or,
		     	SQLBinaryExpression(SQLColumn("name"), .equal, SQLBind("Not Pat"))
		     ))
	}
}
