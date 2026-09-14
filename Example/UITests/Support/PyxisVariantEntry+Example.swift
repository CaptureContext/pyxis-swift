import ExampleTesting

extension PyxisVariantEntry {
	internal static var subscriptionKey: String { "subscription.status" }

	internal static func subscription(_ value: ExampleSubscription) -> Self {
		.init(key: subscriptionKey, value: value.rawValue)
	}
}
