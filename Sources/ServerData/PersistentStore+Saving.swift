//
//  File.swift
//  
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

extension PersistentStore {
	public func save(_ model: Model) async throws {
		_ = try await insert(model, in: container.database)
	}

	public func save(_ model: inout Model) async throws {
		let imodel = model

		let id = try await container.database.withSession { transaction in
			try await insert(imodel, in: transaction)
		}

		if let id {
			model.id = id
		}
	}

	public func save(_ models: inout [Model]) async throws {
		let modelsCopy = models

		let result = try await container.database.withSession { transaction in
			var result: [Model] = []

			for var model in modelsCopy {
				model.id = try await insert(model, in: transaction)
				result.append(model)
			}

			return result
		}

		models = result
	}

	private func insert(_ model: Model, in database: any SQLDatabase) async throws -> Int? {
		let tableExists = await container.tables().contains(Model._$table)
		precondition(tableExists, "\(model) not known to database!")

		try await database.insert(into: Model._$table)
			.ignoringConflicts()
			.model(model, with: .init(nilEncodingStrategy: .asNil))
			.run()

		if let id = model.id {
			return id
		} else {
			let row = try await database.raw("SELECT LAST_INSERT_ID()").first()
			let id = try row?.decode(column: "LAST_INSERT_ID()", as: Int.self)
			return id
		}
	}
}
