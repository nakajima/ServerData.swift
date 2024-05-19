//
//  Container.swift
//
//
//  Created by Pat Nakajima on 5/12/24.
//

import Foundation
import Logging
import NIOCore
import NIOPosix
@preconcurrency import SQLKit

#if canImport(SQLiteKit)
extension SQLDialect {
	func showTables(in database: any SQLDatabase, name: String) -> Set<String> {
		try! Set(database.select().column("name").from("sqlite_master").where("type", .equal, "table").all().wait().map { try $0.decode(column: "name", as: String.self) })
	}

	func truncate(in database: any SQLDatabase, name: String) async throws {
		if !name.contains("test") {
			fatalError("cannot truncate non-test DB")
		}

		for table in showTables(in: database, name: name) {
			try await database.execute(sql: SQLRaw("DELETE FROM \(table);")) { _ in }
		}
	}
}
#endif

#if canImport(MySQLKit)
extension SQLDialect {
	func showTables(in database: any SQLDatabase, name: String) -> Set<String> {
		try! Set(database.raw("SHOW TABLES").all().wait().map { try $0.decode(column: "Tables_in_\(name)", as: String.self) })
	}

	func truncate(in database: any SQLDatabase, name: String) async throws {
		if !name.contains("test") {
			fatalError("cannot truncate non-test DB")
		}

		for table in showTables(in: database, name: name) {
			try await database.execute(sql: SQLRaw("TRUNCATE TABLE \(table);")) { _ in }
		}
	}
}
#endif

// Wraps the DB.
public actor Container: Sendable {
	let name: String
	let database: any SQLDatabase
	let logger: Logger
	let shutdown: @Sendable () -> Void

	public init(name: String, database: any SQLDatabase, logger: Logger = Logger(label: "ServerData Container"), shutdown: @Sendable @escaping () -> Void) throws {
		self.name = name
		self.logger = logger
		self.database = database
		self.shutdown = shutdown
	}

	public func tables() -> Set<String> {
		database.dialect.showTables(in: database, name: name)
	}

	public func truncate() async throws {
		try await database.dialect.truncate(in: database, name: name)
	}

	public func drop() async throws {
		if !name.contains("test") {
			fatalError("cannot drop non-test DB")
		}

		for table in tables() {
			try await database.drop(table: table).run()
		}
	}

	deinit {
		shutdown()
	}
}
