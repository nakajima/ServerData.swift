// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SQLKit

@attached(extension, conformances: StorableModel, names: named(requirement), named(_$table), named(_$columns))
public macro Model(table: String) = #externalMacro(module: "ServerDataMacros", type: "ModelMacro")

@attached(peer)
public macro Column(_ constraints: SQLColumnConstraintAlgorithm..., type: SQLDataType? = nil) = #externalMacro(module: "ServerDataMacros", type: "ColumnMacro")

@freestanding(expression)
public macro SQL<Model: StorableModel>(builder: (Model) -> Bool) -> SQLPredicate<Model> = #externalMacro(module: "ServerDataMacros", type: "SQLMacro")
