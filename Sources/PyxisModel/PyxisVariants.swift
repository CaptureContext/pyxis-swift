import Foundation
import OrderedCollections

/// Requested variants preserve declaration order in memory and encode as a JSON object.
/// Replacements retain their position. Equality compares keys and values, not order.
public struct PyxisVariants: Codable, Equatable, Sendable, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, Sequence {
	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.dictionary == rhs.dictionary
	}

	private var storage: OrderedDictionary<String, String>

	/// Unordered inputs are sorted so decoding and dictionary conversion are deterministic.
	public init(_ dictionary: [String: String] = [:]) {
		self.storage = .init(uniqueKeysWithValues: dictionary.sorted { $0.key < $1.key })
	}

	public init(_ entries: some Sequence<PyxisVariantEntry>) {
		self.storage = [:]
		for entry in entries { storage[entry.key] = entry.value }
	}

	public init(arrayLiteral elements: PyxisVariantEntry...) {
		self.init(elements)
	}

	public init(dictionaryLiteral elements: (String, String)...) {
		self.init(elements.map { .init(key: $0.0, value: $0.1) })
	}

	public init(from decoder: any Decoder) throws {
		try self.init([String: String](from: decoder))
	}

	public var dictionary: [String: String] { .init(uniqueKeysWithValues: storage.map { ($0.key, $0.value) }) }
	public var keys: OrderedSet<String> { storage.keys }
	public var isEmpty: Bool { storage.isEmpty }
	public var count: Int { storage.count }

	public subscript(_ key: String) -> String? {
		get { storage[key] }
		set { storage[key] = newValue }
	}

	public func encode(to encoder: any Encoder) throws {
		// OrderedDictionary's Codable representation is an array; Pyxis uses an object.
		try dictionary.encode(to: encoder)
	}

	public func makeIterator() -> OrderedDictionary<String, String>.Iterator {
		storage.makeIterator()
	}

	public mutating func set(_ entry: PyxisVariantEntry) {
		storage[entry.key] = entry.value
	}

	public func merging(_ other: Self) -> Self {
		var result: Self = self
		for (key, value) in other { result.storage[key] = value }
		return result
	}

	public func filter(_ isIncluded: (Element) throws -> Bool) rethrows -> Self {
		var result: Self = self
		result.storage = try storage.filter(isIncluded)
		return result
	}

	public func mapValues<Value>(_ transform: (String) throws -> Value) rethrows -> [String: Value] {
		var result: [String: Value] = [:]
		for (key, value) in storage { result[key] = try transform(value) }
		return result
	}
}
