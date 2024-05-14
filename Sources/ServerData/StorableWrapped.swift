//
//  StorableWrapped.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
import SQLKit

public protocol StorableWrapped {
	var constraints: [SQLColumnConstraintAlgorithm] { get }

	static func wrappedType() -> Any.Type
}

public protocol StorableAsInt {}
extension Int: StorableAsInt {}

public protocol StorableAsDouble {}
extension Double: StorableAsDouble {}

public protocol StorableAsText {}
extension String: StorableAsText {}

public protocol StorableAsData {}
extension Data: StorableAsData {}

public protocol StorableAsDate {}
extension Date: StorableAsDate {}

protocol OptionalProtocol {
	var wrappedOptionalValue: Any? { get }
}

extension Optional: OptionalProtocol {
	var wrappedOptionalValue: Any? {
		switch self {
		case let .some(w): return w
		default: return nil
		}
	}
}

extension Optional: StorableWrapped {
	public static func wrappedType() -> Any.Type {
		Wrapped.self
	}

	public var constraints: [SQLColumnConstraintAlgorithm] { [] }
}
