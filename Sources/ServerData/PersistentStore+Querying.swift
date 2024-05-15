//
//  PersistentStore+Querying.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation

extension PersistentStore {
	func first(
		where predicate: Predicate<Model>? = nil,
		sort: KeyPathComparator<Model>? = nil
	) async throws -> Model? {
		try await ModelQuery(
			container: container,
			predicate: predicate,
			sort: sort,
			limit: 1
		).list().first
	}

	func list(
		where predicate: Predicate<Model>? = nil,
		sort: KeyPathComparator<Model>? = nil,
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
