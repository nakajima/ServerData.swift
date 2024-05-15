//
//  StorableWrapped.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation
import SQLKit

// Conformances to help figure out what Swift types should map to
// which SQL types when the `type` hasn't been specified.
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
