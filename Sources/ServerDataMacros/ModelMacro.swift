import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SQLKit

struct ColumnOptions {
	var sqlType: String?
	var constraints: [MemberAccessExprSyntax] = []
}

struct Column {
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
				 let type = argument.expression.as(MemberAccessExprSyntax.self)?.declName.baseName {
				columnOptions.sqlType = ".\(type)"
				continue
			}

			if let expression = argument.expression.as(MemberAccessExprSyntax.self) {
				let declName = expression.declName.baseName
				columnOptions.constraints.append(
					.init(name: declName)
				)
			} else if let expression = argument.expression.as(LabeledExprSyntax.self) {
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
				 let arguments = attribute.arguments {
				options = extractColumnOptions(from: arguments)
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

public struct ModelMacro: MemberAttributeMacro, MemberMacro, ExtensionMacro {
	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		guard let typeName = type.as(IdentifierTypeSyntax.self)?.name.text else {
			// TODO: When can this fail?
			return []
		}

		let attributes = Column.extract(from: declaration)

//		let attributeDefinitions: [CodeBlockItemListSyntax] = attributes.map { attribute in
		let attributeDefinitions: [DictionaryElementSyntax] = attributes.map { attribute in
			let key: ExprSyntax = "\\\(raw: typeName).\(raw: attribute.name)"
			let value: ExprSyntax = "ColumnDefinition(name: \(literal: attribute.name), sqlType: \(raw: attribute.sqlType ?? "nil"), swiftType: \(raw: attribute.type).self, isOptional: \(literal: attribute.isOptional), constraints: [\(raw: attribute.constraints.map(\.description).joined(separator: ", "))])"
			return DictionaryElementSyntax(key: key, value: value)
		}

		let sendableExtension: DeclSyntax =
			"""
			extension \(type.trimmed): StorableModel {
				static var _$columnsByKeyPath: [AnyHashable: ColumnDefinition] {
					[
						\(raw: attributeDefinitions.map(\.description).joined(separator: ",\n"))
					]
				}
			}
			"""

		guard let extensionDecl = sendableExtension.as(ExtensionDeclSyntax.self) else {
			return []
		}

		return [extensionDecl]
	}

	///	Supports
	///
	/// 	@Model(table: "people") struct Person {
	/// 		var id: Int?
	/// 		var name: String
	/// 	}
	///
	/// Getting expanded to:
	///
	/// 	struct Person: StorableModel {
	/// 		var id: Int?
	/// 		var name: String
	///
	/// 		static let table = "people"
	/// 	}
	///
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let arguments = node.arguments else {
			// TODO: Add a diagnostic here
			return []
		}

		var tableName: String? = nil
		for argument in arguments.children(viewMode: .fixedUp) {
			guard let labeled = argument.as(LabeledExprSyntax.self),
						let expression = labeled.expression.as(StringLiteralExprSyntax.self),
						let name = expression.segments.first?.as(StringSegmentSyntax.self)?.content else {
				continue
			}

			tableName = name.text
		}

		guard let tableName else {
			// TODO: Add a diagnostic here
			return []
		}

		return [
			"""
			public static let _$table = \(literal: tableName)
			"""
		]
	}

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingAttributesFor member: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [AttributeSyntax] {
		[]
	}
}

// This macro is just defined so we can have a nicely typed @Column() that takes options, we
// parse out the interesting stuff in model macro
public struct ColumnMacro: PeerMacro {
	static public func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		[]
	}
}

@main
struct ServerDataMacroPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		ModelMacro.self,
		ColumnMacro.self
	]
}
