//
//  StorableModel.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
import SQLKit

extension PartialKeyPath: @unchecked Sendable where Root: StorableModel {}

public struct StorableModelAttributeRegistry<Model: StorableModel>: Sendable {
	let namesToDefinitions: [String: ColumnDefinition]
	let keypathsToNames: [PartialKeyPath<Model>: String]

	public init(namesToDefinitions: [String: ColumnDefinition], keypathsToNames: [PartialKeyPath<Model>: String]) {
		self.namesToDefinitions = namesToDefinitions
		self.keypathsToNames = keypathsToNames
	}

	func definition(for name: String) -> ColumnDefinition {
		namesToDefinitions[name]!
	}

	func definition(for keyPath: PartialKeyPath<Model>) -> ColumnDefinition {
		namesToDefinitions[keypathsToNames[keyPath]!]!
	}
}

// Conformace added by the @Model macro
public protocol StorableModel: Codable, Sendable {
	static var _$table: String { get }
	static var _$columns: StorableModelAttributeRegistry<Self> { get }

	var id: Int? { get set }

	static func create(in database: any SQLDatabase) async throws
}

public extension StorableModel {
	// This is defined to get around macro expansion ordering issues. We should never
	// see this actually happen.
	static var _$table: String { fatalError("should have been expanded by the macro") }

	// This is nice for quick prototyping tho I probably wouldn't do it in production.
	static func create(in database: any SQLDatabase) async throws {
		var creator = database.create(table: _$table)

		for column in _$columns.namesToDefinitions.values {
			var constraints = column.constraints

			if !column.isOptional {
				constraints.append(.notNull)
			}

			// TODO: Make this configurable
			if column.name == "id" {
				constraints.append(.primaryKey(autoIncrement: true))
			}

			let type: SQLDataType = if let sqlType = column.sqlType {
				sqlType
			} else {
				switch column.swiftType {
				case is any StorableAsInt.Type: .bigint
				case is any StorableAsDouble.Type: .real
				case is any StorableAsText.Type: .text
				case is any StorableAsData.Type: .blob
				case is any StorableAsDate.Type: .custom(SQLRaw("DATETIME"))
				case is any Codable.Type: .blob
				default:
					fatalError("cannot represent: \(column.swiftType)")
				}
			}

			creator = creator.column(column.name, type: type, constraints)
		}

		try! await creator.run()
	}
}
