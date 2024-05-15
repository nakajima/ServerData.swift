// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SQLKit

@attached(memberAttribute)
@attached(member, names: named(_$table))
@attached(extension, conformances: StorableModel, names: named(requirement), named(_$columnsByKeyPath))
public macro Model(table: String) = #externalMacro(module: "ServerDataMacros", type: "ModelMacro")

@attached(peer)
public macro Column(_ constraints: SQLColumnConstraintAlgorithm..., type: SQLDataType? = nil) = #externalMacro(module: "ServerDataMacros", type: "ColumnMacro")
