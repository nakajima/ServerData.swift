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

extension SQLDialect {
	func showTables(in database: any SQLDatabase, name: String) async throws -> Set<String> {
		#if canImport(SQLiteKit)
		try await Set(database.select().column("name").from("sqlite_master").where("type", .equal, "table").all().get().map { try $0.decode(column: "name", as: String.self) })
		#elseif canImport(MySQLKit)
		try await Set(database.raw("SHOW TABLES").all().get().map { try $0.decode(column: "Tables_in_\(name)", as: String.self) })
		#else
		fatalError("No database adapter found.")
		#endif
	}

	func truncate(in database: any SQLDatabase, name: String) async throws {
		if !name.contains("test") {
			fatalError("cannot truncate non-test DB")
		}

		#if canImport(SQLiteKit)
		for table in try await showTables(in: database, name: name) {
			try await database.execute(sql: SQLRaw("DELETE FROM \(table);")) { _ in }
		}
		#elseif canImport(MySQLKit)
		for table in try await showTables(in: database, name: name) {
			try await database.execute(sql: SQLRaw("TRUNCATE TABLE \(table);")) { _ in }
		}
		#else
		fatalError("No database adapter found.")
		#endif
	}
}

// Wraps the DB.
public actor Container: Sendable {
	let name: String
	let logger: Logger
	let shutdown: @Sendable () -> Void

	public let database: any SQLDatabase

	public init(name: String, database: any SQLDatabase, logger: Logger = Logger(label: "ServerData Container"), shutdown: @Sendable @escaping () -> Void) throws {
		self.name = name
		self.logger = logger
		self.database = database
		self.shutdown = shutdown
	}

	public func tables() async throws -> Set<String> {
		try await database.dialect.showTables(in: database, name: name)
	}

	public func truncate() async throws {
		try await database.dialect.truncate(in: database, name: name)
	}

	public func drop() async throws {
		if !name.contains("test") {
			fatalError("cannot drop non-test DB")
		}

		for table in try await tables() {
			try await database.drop(table: table).run()
		}
	}

	deinit {
		shutdown()
	}
}
