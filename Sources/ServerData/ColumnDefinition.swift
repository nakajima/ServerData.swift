//
//  File.swift
//  
//
//  Created by Pat Nakajima on 5/14/24.
//

import Foundation
import SQLKit

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
