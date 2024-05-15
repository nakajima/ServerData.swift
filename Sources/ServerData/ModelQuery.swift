//
//  ModelQuery.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

public enum Sort<Model: StorableModel> {
	case ascending(PartialKeyPath<Model>), descending(PartialKeyPath<Model>)
}

extension PartialKeyPath where Root: StorableModel {
	var columnDefinition: ColumnDefinition {
		Root._$columnsByKeyPath[self]!
	}
}

struct ModelQuery<Model: StorableModel> {
	let predicate: Predicate<Model>?
	let sort: KeyPathComparator<Model>?
	let limit: Int?
	let container: Container

	init(
		container: Container,
		predicate: Predicate<Model>? = nil,
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

		if let predicate, let expression = PredicateToSQL(predicate: predicate).expressions() {
			query = query.where(expression)
		}

		var sqlSerializer = SQLSerializer(database: container.database)
		query.select.serialize(to: &sqlSerializer)

		if let limit {
			query = query.limit(limit)
		}

		if let sort {
			query = query.orderBy(sort.keyPath.columnDefinition.name, sort.order == .forward ? .ascending : .descending)
		}

		return try await query.all(decoding: Model.self)
	}
}
