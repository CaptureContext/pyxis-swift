import Foundation

/// JSONDecoder accepts duplicate keys; reject them before typed decoding loses that information.
internal struct JSONKeyScanner {
	private var bytes: [UInt8]
	private var position: Int

	internal init(bytes: [UInt8]) {
		self.bytes = bytes
		self.position = 0
	}

	internal mutating func validate() throws {
		try value(depth: 0)
		whitespace()
		guard position == bytes.count
		else { throw PyxisValidationError("Trailing JSON content") }
	}

	private mutating func value(depth: Int) throws {
		guard depth < 128 else {
			throw PyxisValidationError("JSON nesting exceeds 128 levels")
		}

		whitespace()

		guard position < bytes.count
		else { throw PyxisValidationError("Truncated JSON") }

		switch bytes[position] {
		case 123:
			position += 1
			var keys: Set<String> = []

			whitespace()
			if take(125) { return }

			repeat {
				whitespace()

				let key = try string()
				guard keys.insert(key).inserted
				else { throw PyxisValidationError("Duplicate or canonically equivalent JSON object key: \(key)") }

				whitespace()
				guard take(58) else { throw PyxisValidationError("Expected JSON colon") }

				try value(depth: depth + 1)
				whitespace()

				if take(125) { return }
				guard take(44) else { throw PyxisValidationError("Expected JSON comma") }
			} while true

		case 91:
			position += 1
			whitespace()

			if take(93) { return }

			repeat {
				try value(depth: depth + 1)
				whitespace()
				if take(93) { return }
				guard take(44) else { throw PyxisValidationError("Expected JSON comma") }
			} while true

		case 34:
			_ = try string()

		default:
			let start = position

			while position < bytes.count, ![9, 10, 13, 32, 44, 93, 125].contains(bytes[position]) {
				position += 1
			}

			guard position > start else { throw PyxisValidationError("Invalid JSON value") }
			_ = try JSONSerialization.jsonObject(
				with: Data(bytes[start..<position]),
				options: .fragmentsAllowed
			)
		}
	}

	private mutating func string() throws -> String {
		let start = position
		guard take(34) else { throw PyxisValidationError("Expected JSON string") }

		while position < bytes.count {
			let byte = bytes[position]
			position += 1
			if byte == 92 {
				position += 1
			} else if byte == 34 {
				let decoded = try JSONSerialization.jsonObject(
					with: Data(bytes[start..<position]),
					options: .fragmentsAllowed
				)

				guard let string = decoded as? String
				else { throw PyxisValidationError("Invalid JSON string") }
				return string
			}
		}

		throw PyxisValidationError("Unterminated JSON string")
	}

	private mutating func whitespace() {
		while position < bytes.count, [9, 10, 13, 32].contains(bytes[position]) {
			position += 1
		}
	}

	private mutating func take(_ byte: UInt8) -> Bool {
		guard position < bytes.count, bytes[position] == byte
		else { return false }

		position += 1
		return true
	}
}
