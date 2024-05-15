//
//  PredicateToSQL.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

protocol SQLPredicateColumn {
	var name: SQLExpression { get }
}

protocol SQLPredicateValue {
	var sqlExpression: SQLExpression { get }
}

protocol SQLPredicateExpression {
	func expression() -> SQLBinaryExpression
}

protocol SQLPredicateExpressionResult<Result> {
	associatedtype Result: SQLExpression
}

// MARK: Predicate column names

extension PredicateExpressions.KeyPath: SQLPredicateColumn where Root.Output: StorableModel {
	var name: any SQLExpression {
		SQLColumn(keyPath.columnDefinition.name).name
	}
}

// MARK: Predicate values

extension PredicateExpressions.UnaryMinus: SQLPredicateValue where Wrapped.Output: SignedNumeric {
	var sqlExpression: any SQLExpression {
		var value: any SignedNumeric = try! wrapped.evaluate(.init())
		value.negate()
		if let value = value as? any Encodable {
			return SQLBind(value)
		} else {
			// TODO: I think this is safe? We already know it's just a number so I don't think there's an injection risk?
			return SQLRaw("\(value)")
		}
	}
}

extension PredicateExpressions.Value: SQLPredicateValue where Output: Encodable {
	var sqlExpression: any SQLExpression {
		SQLBind(value)
	}
}

extension PredicateExpressions.NilLiteral: SQLPredicateValue {
	var sqlExpression: any SQLExpression {
		SQLLiteral.null
	}
}

extension PredicateExpressions.NilCoalesce: SQLPredicateValue where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	var sqlExpression: any SQLExpression {
		SQLBinaryExpression(
			lhs.name,
			.or,
			rhs.sqlExpression
		)
	}
}

// MARK: Predicate expressions

extension PredicateExpressions.NilCoalesce: SQLPredicateColumn where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	@available(*, deprecated, message: "This doesn't really work yet.")
	var name: any SQLExpression {
		SQLFunction.coalesce(lhs.name, rhs.sqlExpression)
	}
}

extension PredicateExpressions.Equal: SQLPredicateExpression where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	func expression() -> SQLBinaryExpression {
		let columnName = lhs.name
		let expression = rhs.sqlExpression

		return .init(columnName, .equal, expression)
	}
}

extension PredicateExpressions.NotEqual: SQLPredicateExpression where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	func expression() -> SQLBinaryExpression {
		let columnName = lhs.name
		let expression = rhs.sqlExpression

		return .init(columnName, .notEqual, expression)
	}
}

extension PredicateExpressions.Comparison: SQLPredicateExpression where LHS: SQLPredicateColumn, RHS: SQLPredicateValue {
	func expression() -> SQLBinaryExpression {
		let columnName = lhs.name
		let expression = rhs.sqlExpression

		let sqlOp: SQLBinaryOperator? = switch op {
		case .greaterThan: .greaterThan
		case .greaterThanOrEqual: .greaterThanOrEqual
		case .lessThan: .lessThan
		case .lessThanOrEqual: .lessThanOrEqual
		default:
			nil
		}

		guard let sqlOp else {
			// TODO: Maybe throw here instead?
			return .init(SQLRaw("1"), .equal, SQLRaw("0"))
		}

		return .init(columnName, sqlOp, expression)
	}
}

extension PredicateExpressions.Conjunction: SQLPredicateExpression where LHS: SQLPredicateExpression, RHS: SQLPredicateExpression {
	func expression() -> SQLBinaryExpression {
		.init(lhs.expression(), .and, rhs.expression())
	}
}

extension PredicateExpressions.Disjunction: SQLPredicateExpression where LHS: SQLPredicateExpression, RHS: SQLPredicateExpression {
	func expression() -> SQLBinaryExpression {
		.init(lhs.expression(), .or, rhs.expression())
	}
}

struct PredicateToSQL<Model: StorableModel> {
	let predicate: Predicate<Model>

	func expressions() -> (any SQLExpression)? {
		guard let expression = predicate.expression as? SQLPredicateExpression else {
			if #available(macOS 14.4, *) {
				fatalError("Predicate not supported: \(predicate.debugDescription)")
			} else {
				fatalError("Predicate not supported: \(predicate)")
			}
		}

		return expression.expression()
	}
}
