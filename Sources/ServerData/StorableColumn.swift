//
//  StorableColumn.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
import SQLKit

@propertyWrapper public struct StorableColumnX<T: Codable & Sendable>: Sendable, Codable, StorableWrapped {
	public static func wrappedType() -> any Any.Type {
		T.self
	}

	public var wrappedValue: T
	public var constraints: [SQLColumnConstraintAlgorithm] = []

	public enum CodingKeys: CodingKey {
		case wrappedValue
	}

	public init(wrappedValue: T) {
		self.wrappedValue = wrappedValue
		self.constraints = []
	}

	public init(_ constraints: SQLColumnConstraintAlgorithm...) {
		self.wrappedValue = try! DefaultsDecoder().singleValueContainer().decode(T.self)
		self.constraints = constraints
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self.wrappedValue = try container.decode(T.self)
		self.constraints = []
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(wrappedValue)
	}
}
