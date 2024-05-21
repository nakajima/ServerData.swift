//
//  PersistentStore+Querying.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation

// Simple querying operations
public extension PersistentStore {
	func find(id: Int?) async throws -> Model? {
		guard let id else { return nil }

		return try await container.database
			.select()
			.from(Model._$table)
			.columns("*")
			.where("id", .equal, id)
			.first(decoding: Model.self)
	}

	func first(
		where predicate: SQLPredicate<Model>? = nil,
		sort: Sort<Model>? = nil
	) async throws -> Model? {
		try await ModelQuery(
			container: container,
			predicate: predicate,
			sort: sort,
			limit: 1
		).list().first
	}

	func list(
		where predicate: SQLPredicate<Model>? = nil,
		sort: Sort<Model>? = nil,
		limit: Int? = nil
	) async throws -> [Model] {
		try await ModelQuery(
			container: container,
			predicate: predicate,
			sort: sort,
			limit: limit
		).list()
	}
}
