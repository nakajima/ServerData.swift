//
//  ModelQuery.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

// Simple sorting type
public enum Sort<Model: StorableModel> {
	case ascending(PartialKeyPath<Model>),
	     descending(PartialKeyPath<Model>)

	var column: ColumnDefinition {
		switch self {
		case .ascending(let keyPath):
			Model._$columns.definition(for: keyPath)
		case .descending(let keyPath):
			Model._$columns.definition(for: keyPath)
		}
	}

	var order: SQLDirection {
		switch self {
		case .ascending:
			.ascending
		case .descending:
			.descending
		}
	}
}

// Handle logic of building queries
struct ModelQuery<Model: StorableModel> {
	let predicate: SQLPredicate<Model>?
	let sort: Sort<Model>?
	let limit: Int?
	let container: Container

	init(
		container: Container,
		predicate: SQLPredicate<Model>? = nil,
		sort: Sort<Model>? = nil,
		limit: Int? = nil
	) {
		self.container = container
		self.predicate = predicate
		self.sort = sort
		self.limit = limit
	}

	func list() async throws -> [Model] {
		var query = container.database.select().from(Model._$table).columns("*")

		if let predicate {
			query = query.where(predicate.expression())
		}

		var sqlSerializer = SQLSerializer(database: container.database)
		query.select.serialize(to: &sqlSerializer)

		if let limit {
			query = query.limit(limit)
		}

		if let sort {
			query = query.orderBy(sort.column.name, sort.order)
		}

		return try await query.all(decoding: Model.self)
	}
}
