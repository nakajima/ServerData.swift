//
//  DefaultCodable.swift
//
//
//  Created by Pat Nakajima on 5/13/24.
//

import Foundation

public struct DefaultsDecoder: Decoder {
	public var codingPath: [CodingKey] = []
	public var userInfo: [CodingUserInfoKey: Any] = [:]
	public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey { KeyedDecodingContainer(EmptyKeyedDecodingContainer<Key>()) }
	public func unkeyedContainer() throws -> UnkeyedDecodingContainer { EmptyUnkeyedDecodingContainer() }
	public func singleValueContainer() throws -> SingleValueDecodingContainer { EmptySingleValueDecodingContainer() }
}

private struct EmptyKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
	var codingPath: [CodingKey] = []
	var allKeys: [Key] = []
	func contains(_: Key) -> Bool { true }
	func decodeNil(forKey _: Key) throws -> Bool { true }
	func decode(_: Bool.Type, forKey _: Key) throws -> Bool { false }
	func decode(_: String.Type, forKey _: Key) throws -> String { "" }
	func decode(_: Double.Type, forKey _: Key) throws -> Double { 0 }
	func decode(_: Float.Type, forKey _: Key) throws -> Float { 0 }
	func decode(_: Int.Type, forKey _: Key) throws -> Int { 0 }
	func decode(_: Int8.Type, forKey _: Key) throws -> Int8 { 0 }
	func decode(_: Int16.Type, forKey _: Key) throws -> Int16 { 0 }
	func decode(_: Int32.Type, forKey _: Key) throws -> Int32 { 0 }
	func decode(_: Int64.Type, forKey _: Key) throws -> Int64 { 0 }
	func decode(_: UInt.Type, forKey _: Key) throws -> UInt { 0 }
	func decode(_: UInt8.Type, forKey _: Key) throws -> UInt8 { 0 }
	func decode(_: UInt16.Type, forKey _: Key) throws -> UInt16 { 0 }
	func decode(_: UInt32.Type, forKey _: Key) throws -> UInt32 { 0 }
	func decode(_: UInt64.Type, forKey _: Key) throws -> UInt64 { 0 }
	func decode<T>(_: T.Type, forKey _: Key) throws -> T where T: Decodable {
		if T.self == URL.self { return URL(string: "https://apple.com/") as! T }
		if T.self == Data.self { return Data() as! T }
		if T.self == Date.self { return Date.distantPast as! T }
		if let iterableT = T.self as? any CaseIterable.Type, let first = (iterableT.allCases as any Collection).first { return first as! T }
		return try T(from: DefaultsDecoder())
	}

	func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer { EmptyUnkeyedDecodingContainer() }
	func superDecoder() throws -> Decoder { DefaultsDecoder() }
	func superDecoder(forKey _: Key) throws -> Decoder { DefaultsDecoder() }
	func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey _: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
		KeyedDecodingContainer(EmptyKeyedDecodingContainer<NestedKey>())
	}
}

private struct EmptySingleValueDecodingContainer: SingleValueDecodingContainer {
	var codingPath: [CodingKey] = []
	func decodeNil() -> Bool { true }
	func decode(_: Bool.Type) throws -> Bool { false }
	func decode(_: String.Type) throws -> String { "" }
	func decode(_: Double.Type) throws -> Double { 0 }
	func decode(_: Float.Type) throws -> Float { 0 }
	func decode(_: Int.Type) throws -> Int { 0 }
	func decode(_: Int8.Type) throws -> Int8 { 0 }
	func decode(_: Int16.Type) throws -> Int16 { 0 }
	func decode(_: Int32.Type) throws -> Int32 { 0 }
	func decode(_: Int64.Type) throws -> Int64 { 0 }
	func decode(_: UInt.Type) throws -> UInt { 0 }
	func decode(_: UInt8.Type) throws -> UInt8 { 0 }
	func decode(_: UInt16.Type) throws -> UInt16 { 0 }
	func decode(_: UInt32.Type) throws -> UInt32 { 0 }
	func decode(_: UInt64.Type) throws -> UInt64 { 0 }
	func decode<T>(_: T.Type) throws -> T where T: Decodable {
		if T.self == URL.self { return URL(string: "https://apple.com/") as! T }
		if T.self == Data.self { return Data() as! T }
		if let iterableT = T.self as? any CaseIterable.Type, let first = (iterableT.allCases as any Collection).first { return first as! T }
		return try T(from: DefaultsDecoder())
	}
}

private struct EmptyUnkeyedDecodingContainer: UnkeyedDecodingContainer {
	var codingPath: [CodingKey] = []
	var count: Int?
	var isAtEnd: Bool = true
	var currentIndex: Int = 0
	mutating func decodeNil() throws -> Bool { true }
	mutating func decode(_: Bool.Type) throws -> Bool { false }
	mutating func decode(_: String.Type) throws -> String { "" }
	mutating func decode(_: Double.Type) throws -> Double { 0 }
	mutating func decode(_: Float.Type) throws -> Float { 0 }
	mutating func decode(_: Int.Type) throws -> Int { 0 }
	mutating func decode(_: Int8.Type) throws -> Int8 { 0 }
	mutating func decode(_: Int16.Type) throws -> Int16 { 0 }
	mutating func decode(_: Int32.Type) throws -> Int32 { 0 }
	mutating func decode(_: Int64.Type) throws -> Int64 { 0 }
	mutating func decode(_: UInt.Type) throws -> UInt { 0 }
	mutating func decode(_: UInt8.Type) throws -> UInt8 { 0 }
	mutating func decode(_: UInt16.Type) throws -> UInt16 { 0 }
	mutating func decode(_: UInt32.Type) throws -> UInt32 { 0 }
	mutating func decode(_: UInt64.Type) throws -> UInt64 { 0 }
	mutating func decode<T>(_: T.Type) throws -> T where T: Decodable {
		if T.self == URL.self { return URL(string: "file:///") as! T }
		if T.self == Data.self { return Data() as! T }
		if let iterableT = T.self as? any CaseIterable.Type, let first = (iterableT.allCases as any Collection).first { return first as! T }
		return try T(from: DefaultsDecoder())
	}

	mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { EmptyUnkeyedDecodingContainer() }
	mutating func superDecoder() throws -> Decoder { DefaultsDecoder() }
	mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
		KeyedDecodingContainer(EmptyKeyedDecodingContainer<NestedKey>())
	}
}
