import Foundation

public enum PyxisVariantStatus: String, Codable, Sendable {
	case applied = "applied"
	case observed = "observed"
	case unsupported = "unsupported"
	case unverified = "unverified"
}
