//
//  SQLMacro.swift
//
//
//  Created by Pat Nakajima on 5/19/24.
//

import SQLKit
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

struct SQLExpressionMaker {
	let block: CodeBlockItemSyntax
	let context: MacroExpansionContext

	init(block: CodeBlockItemSyntax, context: some MacroExpansionContext) {
		self.block = block
		self.context = context
	}

	func expression() -> ExprSyntaxProtocol {
		switch block.item {
		case let .expr(exprSyntax):
			expression(for: exprSyntax)
		default:
			bail("Cannot handle block item: \(block)", at: block)
		}
	}

	func expression(for exprSyntax: ExprSyntax) -> any ExprSyntaxProtocol {
		switch exprSyntax.kind {
		case .memberAccessExpr:
			return expression(for: exprSyntax.cast(MemberAccessExprSyntax.self))
		case .infixOperatorExpr:
			return expression(for: exprSyntax.cast(InfixOperatorExprSyntax.self))
		case .integerLiteralExpr:
			return expression(for: exprSyntax.cast(IntegerLiteralExprSyntax.self), isNegative: false)
		case .floatLiteralExpr:
			return expression(for: exprSyntax.cast(FloatLiteralExprSyntax.self), isNegative: false)
		case .stringLiteralExpr:
			return expression(for: exprSyntax.cast(StringLiteralExprSyntax.self))
		case .tupleExpr:
			return expression(for: exprSyntax.cast(TupleExprSyntax.self))
		case .declReferenceExpr:
			return expression(for: exprSyntax.cast(DeclReferenceExprSyntax.self))
		case .forceUnwrapExpr:
			return expression(for: exprSyntax.cast(ForceUnwrapExprSyntax.self))
		case .prefixOperatorExpr:
			return expression(for: exprSyntax.cast(PrefixOperatorExprSyntax.self))
		case .functionCallExpr:
			return expression(for: exprSyntax.cast(FunctionCallExprSyntax.self))
		case .arrayExpr:
			return expression(for: exprSyntax.cast(ArrayExprSyntax.self))
		default:
			bail("Unhandled expression kind: \(exprSyntax)", at: exprSyntax)
		}
	}

	func expression(for expr: PrefixOperatorExprSyntax) -> any ExprSyntaxProtocol {
		if expr.operator.tokenKind != .prefixOperator("-") {
			bail("Don't know how to handle prefix operator: \(expr)", at: expr)
		}

		switch expr.expression.kind {
		case .integerLiteralExpr:
			return expression(for: expr.expression.cast(IntegerLiteralExprSyntax.self), isNegative: true)
		case .floatLiteralExpr:
			return expression(for: expr.expression.cast(FloatLiteralExprSyntax.self), isNegative: true)
		default:
			()
		}

		bail("Don't know how to handle prefix operator expression: \(expr)", at: expr)
	}

	func expression(for expr: TupleExprSyntax) -> any ExprSyntaxProtocol {
		// If there are parens around an expression assume it's not an actual tuple because i don't
		// know what that would mean
		let expr = expr.elements.first!.expression

		// Special handling for ?? so we can COALESCE
		if let infixExpr = expr.as(InfixOperatorExprSyntax.self), infixExpr.operator.as(BinaryOperatorExprSyntax.self)?.operator.tokenKind == .binaryOperator("??") {
			let lhs = expression(for: infixExpr.leftOperand)
			let rhs = expression(for: infixExpr.rightOperand)

			return ExprSyntax("SQLPredicateExpressions.Coalesce(\(lhs), \(rhs))")
		} else {
			return expression(for: expr)
		}
	}

	func expression(for expr: ForceUnwrapExprSyntax) -> any ExprSyntaxProtocol {
		if let memberAccessExprSyntax = expr.expression.as(MemberAccessExprSyntax.self),
		   let base = memberAccessExprSyntax.base?.as(DeclReferenceExprSyntax.self),
		   base.baseName.tokenKind == .dollarIdentifier("$0")
		{
			// If we're just referencing a column, remove the exclamationMark
			return expression(for: expr.expression)
		} else {
			return ExprSyntax("SQLPredicateExpressions.Value(\(expr))")
		}
	}

	func expression(for expr: StringLiteralExprSyntax) -> any ExprSyntaxProtocol {
		ExprSyntax("SQLPredicateExpressions.Value(\(literal: expr.representedLiteralValue))")
	}

	func expression(for expr: IntegerLiteralExprSyntax, isNegative: Bool) -> any ExprSyntaxProtocol {
		ExprSyntax("SQLPredicateExpressions.Value(\(raw: isNegative ? "-" : "")\(raw: expr.trimmed.description))")
	}

	func expression(for expr: FloatLiteralExprSyntax, isNegative: Bool) -> any ExprSyntaxProtocol {
		ExprSyntax("SQLPredicateExpressions.Value(\(raw: isNegative ? "-" : "")\(raw: expr.trimmed.description))")
	}

	func expression(for expr: ArrayExprSyntax) -> any ExprSyntaxProtocol {
		let elements = expr.elements.map { expression(for: $0.expression).as(ExprSyntax.self)! }

		return ArrayExprSyntax(expressions: elements)
	}

	//	Recursively generates something like:
	//	SQLPredicateExpressions.SQLPredicateBinaryExpression(
	//		"id",
	//		.equal,
	//		123
	//	)
	func expression(for expr: InfixOperatorExprSyntax) -> some ExprSyntaxProtocol {
		let opExpr = expr.operator.cast(BinaryOperatorExprSyntax.self)

		// Special case for "??" since it shouold coalesce
		if opExpr.operator.tokenKind == .binaryOperator("??") {
			let lhs = expression(for: expr.leftOperand)
			let rhs = expression(for: expr.rightOperand)

			return ExprSyntax("SQLPredicateExpressions.Coalesce(\(lhs), \(rhs))")
		}

		let lhs = expression(for: expr.leftOperand)
		let op = binaryOperator(for: expr.operator.cast(BinaryOperatorExprSyntax.self))
		let rhs = expression(for: expr.rightOperand)

		let labeledExpr = LabeledExprListSyntax {
			LabeledExprSyntax(leadingTrivia: "\n", expression: lhs)
			LabeledExprSyntax(leadingTrivia: "\n", expression: op)
			LabeledExprSyntax(leadingTrivia: "\n", expression: rhs)
		}

		let indentedLabeledExpr = Indenter.indent(labeledExpr, indentation: .tab)

		return ExprSyntax(stringLiteral:
			"""
			SQLPredicateExpressions.SQLPredicateBinaryExpression(\(indentedLabeledExpr)\n)
			"""
		)
	}

	func binaryOperator(for expr: BinaryOperatorExprSyntax) -> any ExprSyntaxProtocol {
		let expr: ExprSyntax = switch expr.operator.tokenKind {
		case let .binaryOperator(string):
			switch string {
			case "==": ".equal"
			case "!=": ".notEqual"
			case "&&": ".and"
			case ">": ".greaterThan"
			case ">=": ".greaterThanOrEqual"
			case "<": ".lessThan"
			case "<=": ".lessThanOrEqual"
			case "||": ".or"
			default:
				bail("Unhandled binary operator: \(expr)", at: expr)
			}
		default:
			bail("Unhandled binary operator: \(expr)", at: expr)
		}

		return expr
	}

	func expression(for expr: MemberAccessExprSyntax) -> some ExprSyntaxProtocol {
		ExprSyntax("SQLPredicateExpressions.Column(\(literal: expr.declName.baseName.text))")
	}

	func expression(for token: TokenSyntax) -> some ExprSyntaxProtocol {
		switch token.tokenKind {
		case let .identifier(text):
			ExprSyntax(literal: text)
		default:
			bail("Unhandled token kind: \(token)", at: token)
		}
	}

	func expression(for call: FunctionCallExprSyntax) -> some ExprSyntaxProtocol {
		func findColumn() -> (any ExprSyntaxProtocol)? {
			guard let firstArgument = call.arguments.first?.expression else {
				return nil
			}

			switch firstArgument.kind {
			case .memberAccessExpr:
				if case let .identifier(columnName) = firstArgument.cast(MemberAccessExprSyntax.self).declName.baseName.tokenKind {
					return ExprSyntax("SQLPredicateExpressions.Column(\(literal: columnName))")
				}
			case .infixOperatorExpr:
				let argExpr = firstArgument.cast(InfixOperatorExprSyntax.self)
				return expression(for: argExpr)
			default:
				()
			}

			return expression(for: firstArgument)
		}

		func findValue() -> (any ExprSyntaxProtocol)? {
			switch call.calledExpression.kind {
			case .memberAccessExpr:
				let memberExpr = call.calledExpression.cast(MemberAccessExprSyntax.self)

				guard memberExpr.declName.baseName.tokenKind == .identifier("contains") else {
					context.diagnose(.init(node: memberExpr.declName, message: MacroExpansionErrorMessage("Only contains() functions work right now")))
					return nil
				}

				guard let memberExprBase = memberExpr.base else {
					return nil
				}

				return expression(for: memberExprBase)
			default:
				()
			}

			return nil
		}

		let lhs = findColumn()
		let rhs = findValue()

		if let lhs, let rhs {
			let op = ExprSyntax(".in")

			let labeledExpr = LabeledExprListSyntax {
				LabeledExprSyntax(leadingTrivia: "\n", expression: lhs)
				LabeledExprSyntax(leadingTrivia: "\n", expression: op)
				LabeledExprSyntax(leadingTrivia: "\n", expression: rhs)
			}

			let indentedLabeledExpr = Indenter.indent(labeledExpr, indentation: .tab)

			return ExprSyntax(stringLiteral:
				"""
				SQLPredicateExpressions.SQLPredicateBinaryExpression(\(indentedLabeledExpr)\n)
				"""
			)
		}

		return ExprSyntax("\(raw: "DummyExpression()")")
	}

	func expression(for expr: DeclReferenceExprSyntax) -> some ExprSyntaxProtocol {
		ExprSyntax("SQLPredicateExpressions.Value(\(expr.trimmed))")
	}

	func bail(_ message: String, at node: some SyntaxProtocol) -> Never {
		context.diagnose(.init(node: node, message: MacroExpansionErrorMessage(message)))
		fatalError(message)
	}
}

public struct SQLMacro: ExpressionMacro {
	public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
		guard let node = node.as(MacroExpansionExprSyntax.self) else {
			context.diagnose(.init(node: node, message: MacroExpansionErrorMessage("Could not figure out SQL expansion node")))
			fatalError()
		}

		guard let blockSyntax = node.trailingClosure?.statements.as(CodeBlockItemListSyntax.self)?.first else {
			context.diagnose(.init(node: node, message: MacroExpansionErrorMessage("Could not get code block: \(node.trimmedDescription)")))
			return ExprSyntax("")
		}

		let expression = SQLExpressionMaker(block: blockSyntax, context: context).expression()

		let result: ExprSyntax = """
		SQLPredicate(expression:
		\(expression)
		)
		"""

		return result
	}
}
