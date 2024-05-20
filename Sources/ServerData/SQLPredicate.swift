//
//  SQLPredicate.swift
//
//
//  Created by Pat Nakajima on 5/19/24.
//

import Foundation
import SQLKit

// Namespace
public enum SQLPredicateExpressions {}

public protocol SQLPredicateExpression {
	func expression() -> any SQLExpression
}

public extension SQLPredicateExpressions {
	struct Coalesce: SQLPredicateExpression {
		public var values: [any SQLPredicateExpression]

		public init(_ values: any SQLPredicateExpression...) {
			self.values = values
		}

		public func expression() -> any SQLExpression {
			SQLFunction.coalesce(values.map { $0.expression() })
		}
	}

	struct Column: SQLPredicateExpression {
		public var column: SQLColumn

		public init(_ name: String) {
			self.column = SQLColumn(name)
		}

		public func expression() -> any SQLExpression {
			column.name
		}
	}

	struct Operator {
		public var `operator`: SQLBinaryOperator
	}

	struct Value<V: Encodable & Sendable>: SQLPredicateExpression {
		public var value: SQLExpression

		public init(_ value: V) {
			self.value = SQLBind(value)
		}

		public func expression() -> any SQLExpression {
			value
		}
	}

	struct SQLPredicateBinaryExpression: SQLPredicateExpression {
		public var lhs: SQLPredicateExpression
		public var `operator`: SQLBinaryOperator
		public var rhs: SQLPredicateExpression

		public init(_ lhs: SQLPredicateExpression, _ op: SQLBinaryOperator, _ rhs: SQLPredicateExpression) {
			self.lhs = lhs
			self.operator = op
			self.rhs = rhs
		}

		public func expression() -> any SQLExpression {
			SQLBinaryExpression(lhs.expression(), self.operator, rhs.expression())
		}
	}
}

public struct SQLPredicate<each Model: StorableModel> {
	public var sqlPredicateExpression: SQLPredicateExpression

	public init(expression: SQLPredicateExpression) {
		self.sqlPredicateExpression = expression
	}

	public func expression() -> any SQLExpression {
		sqlPredicateExpression.expression()
	}
}
