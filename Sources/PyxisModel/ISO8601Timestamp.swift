import Foundation

/// A wire adapter that keeps model dates independent of encoder/decoder date strategies.
internal struct ISO8601Timestamp: Codable {
	internal let value: Date

	internal init(_ value: Date) {
		self.value = value
	}

	internal init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let text = try container.decode(String.self)
		do {
			try self.init(Self.parse(text))
		} catch {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 timestamp: \(text)")
		}
	}

	internal func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		let text: String
		do {
			text = try Self.string(from: self.value)
		} catch {
			throw EncodingError.invalidValue(self.value, .init(
				codingPath: encoder.codingPath,
				debugDescription: "Date is outside the manifest timestamp range",
				underlyingError: error
			))
		}
		try container.encode(text)
	}

	internal static func validate(_ value: Date) throws {
		let seconds = value.timeIntervalSince1970
		// Gregorian years 0001–9999, including the contract's maximum timezone offset.
		guard seconds.isFinite, seconds >= -62_135_596_800 - 86_340, seconds < 253_402_300_800 + 86_340
		else { throw PyxisValidationError("Date is outside the manifest timestamp range") }
	}

	private static func string(from value: Date) throws -> String {
		try validate(value)
		let seconds = value.timeIntervalSinceReferenceDate
		let whole = floor(seconds)
		var fraction = String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), seconds - whole)
		let carry: Double = fraction.hasPrefix("1") ? 1 : 0
		fraction.removeFirst()
		while fraction.last == "0" { fraction.removeLast() }
		if fraction == "." { fraction = "" }

		let date = Date(timeIntervalSinceReferenceDate: whole + carry)
		try validate(date)
		let unix = date.timeIntervalSince1970
		let offset = unix < -62_135_596_800 ? 86_340 : unix >= 253_402_300_800 ? -86_340 : 0
		let text = formatter().string(from: date.addingTimeInterval(Double(offset)))
		let timezone = offset == 0 ? "Z" : offset > 0 ? "+23:59" : "-23:59"
		return String(text.prefix(19)) + fraction + timezone
	}

	private static func formatter() -> DateFormatter {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.calendar = Calendar(identifier: .gregorian)
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		// The manifest uses Gregorian dates even before the historical 1582 cutover.
		formatter.gregorianStartDate = Date(timeIntervalSince1970: -100_000_000_000)
		formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
		formatter.isLenient = false
		return formatter
	}

	internal static func parse(_ value: String) throws -> Date {
		let pattern = #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})\z"#

		guard value.range(of: pattern, options: .regularExpression) != nil
		else { throw PyxisValidationError("Expected ISO 8601 timestamp with timezone") }

		let parts = value.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
		guard parts.count >= 6 else { throw PyxisValidationError("Invalid timestamp") }

		let year = parts[0]
		let month = parts[1]
		let leapYear = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
		let monthDays = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

		guard
			(1...9_999).contains(year), (1...12).contains(month),
			(1...monthDays[month - 1]).contains(parts[2]),
			(0...23).contains(parts[3]), (0...59).contains(parts[4]), (0...59).contains(parts[5])
		else { throw PyxisValidationError("Invalid calendar timestamp") }

		var offsetSeconds = 0
		if !value.hasSuffix("Z") {
			let offset = value.suffix(5).split(separator: ":").compactMap { Int($0) }
			guard offset.count == 2, offset[0] <= 23, offset[1] <= 59
			else { throw PyxisValidationError("Invalid timezone offset") }
			offsetSeconds = (offset[0] * 3_600 + offset[1] * 60) * (value.suffix(6).first == "-" ? -1 : 1)
		}

		let whole = String(value.prefix(19)) + "Z"
		guard let date = formatter().date(from: whole)
		else { throw PyxisValidationError("Invalid timestamp") }

		let fraction: Double
		if let dot = value.firstIndex(of: ".") {
			let digits = value[value.index(after: dot)...].prefix(while: { $0.isNumber })
			fraction = Double("0." + digits) ?? 0
		} else {
			fraction = 0
		}
		return date.addingTimeInterval(-Double(offsetSeconds)).addingTimeInterval(fraction)
	}
}
