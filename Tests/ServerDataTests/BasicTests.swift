//
//  BasicTests.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
import MySQLKit
@testable import ServerData
import SQLKit
import XCTest

@Model(table: "test_models") struct TestModel: Sendable {
	var id: Int?
	@Column(.unique) var name: String
	var birthday: Date
}

class MetaTests: XCTestCase {
	var store: PersistentStore<TestModel>!

	override func setUp() async throws {
		var configuration = MySQLConfiguration(url: ProcessInfo.processInfo.environment["MYSQL_URL"]!)!
		configuration.database = "server_data_test"
		configuration.tlsConfiguration?.certificateVerification = .none

		let source = MySQLConnectionSource(configuration: configuration)
		let pool = EventLoopGroupConnectionPool(source: source, on: MultiThreadedEventLoopGroup(numberOfThreads: 2))
		let mysql = pool.database(logger: Logger(label: "test"))

		let container = try Container(name: "server_data_test", database: mysql.sql()) { pool.shutdown() }

		store = PersistentStore(for: TestModel.self, container: container)

		// Make sure setup can create the table
		try await store.container.drop()
		await store.setup()
	}

	func testBasic() async throws {
		let pat = TestModel(name: "Pat", birthday: .distantPast)
		let baby = TestModel(name: "Baby", birthday: .distantFuture)

		XCTAssertEqual("Pat", pat.name)

		try await store.save(pat)
		try await store.save(baby)

		let count = try await store.list().count
		XCTAssertEqual(count, 2)

		let result1 = try await store.list(
			where: #Predicate {
				$0.name == "Pat"
			}
		)

		XCTAssertEqual(result1.count, 1)
		XCTAssertEqual("Pat", result1[0].name)

		let result2 = try await store.first(sort: .init(\.birthday, order: .reverse))
		XCTAssertEqual("Baby", result2?.name)

		// Make sure .unique is working
		let pat2 = TestModel(name: "Pat", birthday: Date())
		try await store.save(pat2)
		let result3 = try await store.list(where: #Predicate { $0.name == "Pat" })
		XCTAssertEqual(1, result3.count)
	}

	func testColumns() async throws {
		let attributes = TestModel._$columnsByKeyPath
		XCTAssertEqual(3, attributes.count)
		XCTAssertEqual(attributes[\TestModel.id]!.description, ColumnDefinition(name: "id", sqlType: nil, swiftType: Int.self, isOptional: true, constraints: []).description)
		XCTAssertEqual(attributes[\TestModel.name]!.description, ColumnDefinition(name: "name", sqlType: nil, swiftType: String.self, isOptional: false, constraints: [.unique]).description)
		XCTAssertEqual(attributes[\TestModel.birthday]!.description, ColumnDefinition(name: "birthday", sqlType: nil, swiftType: Date.self, isOptional: false, constraints: []).description)
	}
}
