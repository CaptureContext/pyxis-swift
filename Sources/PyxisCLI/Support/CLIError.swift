internal enum CLIError: Error, CustomStringConvertible {
	case operation(String)

	internal var description: String {
		switch self {
		case let .operation(message): message
		}
	}
}
