//
//  BasicTests.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
@testable import ServerData
import SQLiteKit
import SQLKit
import XCTest

@Model(table: "test_models") struct TestModel: Sendable {
	@Column(.primaryKey(autoIncrement: true)) var id: Int?
	@Column(.unique) var name: String
	var birthday: Date
	var favoriteColor: String?
}

extension EventLoopGroupConnectionPool: @unchecked Sendable {}

extension Container {
	static func test() -> Container {
		// Configure our SQLite database so we can create a ServerData Container
		let config = SQLiteConfiguration(storage: .memory)
		let source = SQLiteConnectionSource(configuration: config)
		let pool = EventLoopGroupConnectionPool(source: source, on: MultiThreadedEventLoopGroup(numberOfThreads: 2))
		let connection = try! source.makeConnection(logger: Logger(label: "test"), on: pool.eventLoopGroup.next()).wait()
		let database = connection.sql()

		// Create the Container so we can use it to create a PersistentStore for
		// our Person model
		let container = try! Container(
			name: "test",
			database: database,
			shutdown: {
				pool.shutdown()
				try! connection.close().wait()
			}
		)

		return container
	}
}

class BasicTests: XCTestCase {
	var store: PersistentStore<TestModel>!

	override func setUp() async throws {
		let container = Container.test()

		store = PersistentStore(for: TestModel.self, container: container)

		// Make sure setup can create the table
		try await store.container.drop()
		await store.setup()
	}

	func testBasic() async throws {
		let pat = TestModel(name: "Pat", birthday: .distantPast)
		let baby = TestModel(name: "Baby", birthday: .distantFuture)

		try await store.save(pat)
		try await store.save(baby)

		let count = try await store.list().count
		XCTAssertEqual(count, 2)

		let result1 = try await store.list(
			where: #SQL {
				$0.name == "Pat"
			}
		)

		XCTAssertEqual(result1.count, 1)
		XCTAssertEqual("Pat", result1[0].name)

		let result2 = try await store.first(sort: .descending(\.birthday))
		XCTAssertEqual("Baby", result2?.name)

		// Make sure .unique is working
		let pat2 = TestModel(name: "Pat", birthday: Date())
		try await store.save(pat2)
		let result3 = try await store.list(where: #SQL { $0.name == "Pat" })
		XCTAssertEqual(1, result3.count)
	}

	func testDelete() async throws {
		let a = TestModel(name: "a", birthday: .distantPast, favoriteColor: "blue")
		let b = TestModel(name: "b", birthday: Date().addingTimeInterval(-1000), favoriteColor: "blue")
		let c = TestModel(name: "c", birthday: Date().addingTimeInterval(1000), favoriteColor: "green")

		try await store.save([a, b, c])
		try await store.delete(where: #SQL { $0.name == "a" })

		let newList = try await store.list()
		XCTAssertEqual(newList.count, 2)

		XCTAssertEqual(["b", "c"], newList.map(\.name))
	}

	func testCompoundPredicate() async throws {
		let a = TestModel(name: "a", birthday: .distantPast, favoriteColor: "blue")
		let b = TestModel(name: "b", birthday: Date().addingTimeInterval(-1000), favoriteColor: "blue")
		let c = TestModel(name: "c", birthday: Date().addingTimeInterval(1000), favoriteColor: "green")
		let d = TestModel(name: "d", birthday: .distantFuture, favoriteColor: "green")

		try await store.save([a, b, c, d])

		let date = Date()
		let result = try await store.list(where: #SQL {
			$0.favoriteColor == "green" && $0.birthday > date
		})

		XCTAssertEqual(result.count, 2)
	}

	func testColumns() async throws {
		let attributes: [PartialKeyPath<TestModel>: ColumnDefinition] = TestModel._$columns.keypathsToNames.reduce(into: [:]) { result, item in
			result[item.key] = TestModel._$columns.definition(for: item.value)
		}
		XCTAssertEqual(
			attributes[\TestModel.id]!.description,
			ColumnDefinition(name: "id", sqlType: nil, swiftType: Int.self, isOptional: true, constraints: []).description
		)
		XCTAssertEqual(
			attributes[\TestModel.name]!.description,
			ColumnDefinition(name: "name", sqlType: nil, swiftType: String.self, isOptional: false, constraints: [.unique]).description
		)
		XCTAssertEqual(
			attributes[\TestModel.birthday]!.description,
			ColumnDefinition(name: "birthday", sqlType: nil, swiftType: Date.self, isOptional: false, constraints: []).description
		)
		XCTAssertEqual(
			attributes[\TestModel.favoriteColor]!.description,
			ColumnDefinition(name: "favoriteColor", sqlType: nil, swiftType: String.self, isOptional: true, constraints: []).description
		)
	}
}
