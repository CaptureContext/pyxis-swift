import ArgumentParser

internal func requireNonempty(
	_ value: String,
	name: String
) throws {
	guard !value.isEmpty
	else { throw ArgumentParser.ValidationError("\(name) must not be empty.") }
}
