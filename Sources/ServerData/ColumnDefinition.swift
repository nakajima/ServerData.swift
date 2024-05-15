//
//  ColumnDefinition.swift
//
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

// Contains information about a column. This gets populated from the @Model macro, along
// with some metadata from the @Column macro which doesn't do anything besides sit there
// waiting to be parsed by swift-syntax.
public struct ColumnDefinition: Sendable {
	public var name: String
	public var sqlType: SQLDataType?
	public var swiftType: Any.Type
	public var isOptional: Bool
	public var constraints: [SQLColumnConstraintAlgorithm]
}

extension ColumnDefinition: CustomStringConvertible {
	public var description: String {
		"ColumnDefinitiona(name: \(name.debugDescription), sqlType: \(sqlType.debugDescription), swiftType: \(swiftType).self, isOptional: \(isOptional), constraints: \(constraints.debugDescription))"
	}
}
