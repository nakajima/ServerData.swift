import SQLKit
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ColumnOptions {
	var sqlType: String?
	var constraints: [MemberAccessExprSyntax] = []
}

// Keeps track of column information pulled out of the syntax
struct Column: Equatable {
	var name: String
	var type: String
	var sqlType: String?
	var isOptional: Bool
	var constraints: [MemberAccessExprSyntax] = []

	static func extractColumnOptions(from arguments: AttributeSyntax.Arguments) -> ColumnOptions {
		var columnOptions = ColumnOptions()

		for argument in arguments.children(viewMode: .fixedUp) {
			guard let argument = argument.as(LabeledExprSyntax.self) else {
				continue
			}

			if let label = argument.label, label.text == "type",
			   let type = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName
			{
				columnOptions.sqlType = ".\(type)"
				continue
			}

			if let expression = argument.expression.as(MemberAccessExprSyntax.self) {
				let declName = expression.declName.baseName
				columnOptions.constraints.append(
					.init(name: declName)
				)
			} else if argument.expression.as(LabeledExprSyntax.self) != nil {
				guard let label = argument.label?.text, label == "type" else {
					// TODO: handle
					continue
				}
			}
		}

		return columnOptions
	}

	static func extract(from declaration: some DeclGroupSyntax) -> [Column] {
		var columns: [Column] = []

		for member in declaration.memberBlock.members {
			guard let decl = member.decl.as(VariableDeclSyntax.self), decl.bindingSpecifier.tokenKind == .keyword(.var) else {
				// It's not a var so we don't need to worry about persisting it
				continue
			}

			var options = ColumnOptions()
			if let attribute = decl.attributes.first?.as(AttributeSyntax.self),
			   let attributeIdentifierToken = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name,
			   attributeIdentifierToken.tokenKind == .identifier("Column"),
			   let arguments = attribute.arguments
			{
				options = extractColumnOptions(from: arguments)
			}

			if let attribute = decl.attributes.first?.as(AttributeSyntax.self),
				 let attributeIdentifierToken = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name,
				 attributeIdentifierToken.tokenKind == .identifier("Transient")
			{
				continue
			}

			guard let firstBinding = decl.bindings.first?.as(PatternBindingSyntax.self) else {
				continue
			}

			guard let name = firstBinding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
				// TODO: When will this fail?
				continue
			}

			guard let typeAnnotation = firstBinding.typeAnnotation?.type.as(TypeSyntax.self) else {
				// TODO: When will this fail?
				continue
			}

			var isOptional = false
			var typeIdentifier: IdentifierTypeSyntax?
			if let type = typeAnnotation.as(OptionalTypeSyntax.self) {
				isOptional = true
				typeIdentifier = type.wrappedType.as(IdentifierTypeSyntax.self)
			} else if let type = typeAnnotation.as(IdentifierTypeSyntax.self) {
				typeIdentifier = type
			} else {
				// TODO: When will this fail?
				continue
			}

			guard let type = typeIdentifier?.name.text else {
				// TODO: When will this fail?
				continue
			}

			columns.append(Column(name: name, type: type, sqlType: options.sqlType, isOptional: isOptional, constraints: options.constraints))
		}

		return columns
	}
}

public struct ModelMacro: ExtensionMacro {
	static func extractTableName(from node: AttributeSyntax) -> DeclSyntax? {
		guard let arguments = node.arguments else {
			// TODO: Add a diagnostic here
			return nil
		}

		var tableName: String? = nil
		for argument in arguments.children(viewMode: .fixedUp) {
			guard let labeled = argument.as(LabeledExprSyntax.self),
			      let expression = labeled.expression.as(StringLiteralExprSyntax.self),
			      let name = expression.segments.first?.as(StringSegmentSyntax.self)?.content
			else {
				continue
			}

			tableName = name.text
		}

		guard let tableName else {
			// TODO: Add a diagnostic here
			return nil
		}

		return """
		static let _$table = \(literal: tableName)
		"""
	}

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo _: [TypeSyntax],
		in _: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		guard let typeName = type.as(IdentifierTypeSyntax.self)?.name.text else {
			// TODO: When can this fail?
			return []
		}

		guard let table = extractTableName(from: node) else {
			// TODO: Add a diagnostic
			return []
		}

		let attributes = Column.extract(from: declaration)

//		let attributeDefinitions: [CodeBlockItemListSyntax] = attributes.map { attribute in
		let namesToDefinitions = DictionaryExprSyntax(
			content: .elements(DictionaryElementListSyntax {
				for attribute in attributes {
					DictionaryElementSyntax(
						leadingTrivia: .newline,
						key: ExprSyntax(literal: attribute.name),
						value: ExprSyntax("ColumnDefinition(name: \(literal: attribute.name), sqlType: \(raw: attribute.sqlType ?? "nil"), swiftType: \(raw: attribute.type).self, isOptional: \(literal: attribute.isOptional), constraints: [\(raw: attribute.constraints.map(\.description).joined(separator: ", "))])"),
						trailingTrivia: attribute == attributes.last ? .newline : nil
					)
				}
			})
		)

		let keypathsToNames = DictionaryExprSyntax(
			content: .elements(DictionaryElementListSyntax {
				for attribute in attributes {
					DictionaryElementSyntax(
						key: ExprSyntax("\\\(raw: typeName).\(raw: attribute.name)"),
						value: ExprSyntax(literal: attribute.name)
					)
				}
			}),
			trailingTrivia: .newline
		)

		let sendableExtension: DeclSyntax =
			"""
			extension \(type.trimmed): StorableModel {
				public \(raw: table.description)
				public static let _$columns = StorableModelAttributeRegistry<\(type.trimmed)>(
					namesToDefinitions: \(namesToDefinitions),
					keypathsToNames: \(keypathsToNames))
			}
			"""

		guard let extensionDecl = sendableExtension.as(ExtensionDeclSyntax.self) else {
			return []
		}

		return [extensionDecl]
	}
}

// This macro is just defined so we can have a nicely typed @Column() that takes options, we
// parse out the interesting stuff in model macro
public struct ColumnMacro: PeerMacro {
	public static func expansion(
		of _: AttributeSyntax,
		providingPeersOf _: some DeclSyntaxProtocol,
		in _: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		[]
	}
}

// This macro is just defined so we can have a nicely typed @Transient macro to ignore properties
public struct TransientMacro: PeerMacro {
	public static func expansion(
		of _: AttributeSyntax,
		providingPeersOf _: some DeclSyntaxProtocol,
		in _: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		[]
	}
}

@main
struct ServerDataMacroPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		ModelMacro.self,
		ColumnMacro.self,
		TransientMacro.self,
		SQLMacro.self,
	]
}
