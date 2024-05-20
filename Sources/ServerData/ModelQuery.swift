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
	case ascending(PartialKeyPath<Model>), descending(PartialKeyPath<Model>)
}

// Handle logic of building queries
struct ModelQuery<Model: StorableModel> {
	let predicate: SQLPredicate<Model>?
	let sort: KeyPathComparator<Model>?
	let limit: Int?
	let container: Container

	init(
		container: Container,
		predicate: SQLPredicate<Model>? = nil,
		sort: KeyPathComparator<Model>? = nil,
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
			query = query.orderBy(Model._$columns.definition(for: sort.keyPath).name, sort.order == .forward ? .ascending : .descending)
		}

		return try await query.all(decoding: Model.self)
	}
}
