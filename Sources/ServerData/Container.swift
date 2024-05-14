//
//  DB.swift
//
//
//  Created by Pat Nakajima on 5/12/24.
//

import Foundation
import Logging
import NIOCore
import NIOPosix
import SQLKit

public actor Container: Sendable {
	let name: String
	let database: any SQLDatabase
	let logger: Logger
	let onClose: () -> Void

	public init(name: String, database: any SQLDatabase, logger: Logger = Logger(label: "envelope DB"), onClose: @escaping () -> Void) throws {
		self.name = name
		self.logger = logger
		self.database = database
		self.onClose = onClose
	}
	
	// TODO: Make this cross compatible
	public func tables() -> Set<String> {
		try! Set(database.raw("SHOW TABLES").all().wait().map { try $0.decode(column: "Tables_in_\(self.name)", as: String.self) })
	}

	public func truncate() async throws {
		if !name.contains("test") {
			fatalError("cannot truncate non-test DB")
		}

		for table in tables() {
			try await database.execute(sql: SQLRaw("TRUNCATE TABLE \(table);")) { _ in }
		}
	}

	public func drop() async throws {
		if !name.contains("test") {
			fatalError("cannot drop non-test DB")
		}

		for table in tables() {
			try await database.execute(sql: SQLRaw("DROP TABLE \(table)")) { _ in }
		}
	}

	deinit {
		onClose()
	}
}
