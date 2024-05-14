//
//  File.swift
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

protocol SQLPredicateColumn {
	var name: String { get }
}

protocol SQLPredicateValue {
	var sqlExpression: SQLExpression { get }
}

protocol SQLPredicateExpression {
	func operation() -> (String, SQLBinaryOperator, SQLExpression)
}

extension PredicateExpressions.KeyPath: SQLPredicateColumn where Root.Output: StorableModel {
	var name: String {
		// I know.
		self.keyPath.columnDefinition.name
	}
}

extension PredicateExpressions.Equal: SQLPredicateExpression where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	func operation() -> (String, SQLBinaryOperator, SQLExpression) {
		let columnName = lhs.name
		let expression = rhs.sqlExpression

		return (columnName, .equal, expression)
	}
}

extension PredicateExpressions.Value: SQLPredicateValue where Output: Encodable {
	var sqlExpression: any SQLKit.SQLExpression {
		SQLBind(value)
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

		if let expression = predicate?.expression as? SQLPredicateExpression {
			let (lhs, op, rhs) = expression.operation()

			var serializer = SQLSerializer(database: container.database)
			rhs.serialize(to: &serializer)

			query = query.where(SQLBinaryExpression(SQLColumn(lhs), op, rhs))
		}

		if let limit {
			query = query.limit(limit)
		}

		if let sort {
			query = query.orderBy(sort.keyPath.columnDefinition.name, sort.order == .forward ? .ascending : .descending)
		}

		return try await query.all(decoding: Model.self)
	}
}
