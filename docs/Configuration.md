# Configuration and scopes

Import PyxisRuntime in app bootstrap, PyxisXCTest in recording tests, or PyxisCore in shared app components that only read configuration. Runtime and XCTest selectively export the same configuration declarations. XCTest does not depend on Runtime. No swift-dependencies integration is required.

## Typed entries and capabilities

Define a key with a Sendable value. A capability can be a Sendable closure or a thread-safe service value. Defaults should be side-effect-free.

```swift
import PyxisCore

internal enum SubscriptionStatusKey: PyxisConfigurationKey {
	internal static let defaultValue: String = "none"
}

internal extension PyxisConfiguration {
	var subscriptionStatus: String {
		get { self[SubscriptionStatusKey.self] }
		set { self[SubscriptionStatusKey.self] = newValue }
	}
}

internal struct SubscriptionReader {
	@Pyxis(SubscriptionStatusKey.self)
	internal var status: String
}
```

Readers also accept a Sendable key path, such as `@Pyxis(\.subscriptionStatus)`. They resolve the effective configuration on every access. Constructing a reader inside a scope does not permanently capture that scope.

`pyxisConfiguration` returns a value snapshot. Its `requested` and `report` properties describe bootstrap and are read-only to consumers. Custom typed entries can be modified in a configuration value. Copies isolate dictionary mutations; reference-type capabilities stored in the dictionary retain their own sharing semantics.

## Preparing the process

```swift
import PyxisRuntime

let report = try preparePyxis(adapters: adapters) { configuration in
	configuration.subscriptionStatus = configuration.requested["subscription.status"] ?? "none"
}
```

Call preparation at app startup on the main actor. The environment parameter defaults to the current process environment. With no launch payload, preparation returns nil and leaves the app unchanged. Supplying an explicit empty environment also does nothing. The discardable optional result contains capability results for a valid payload.

Preparation starts from the process default, independently of any surrounding scoped override. It builds typed values, runs adapters in the staged context, validates the report, and publishes configuration plus report under one lock. No user callback executes while the lock is held. Publication is permitted once per process; concurrent/reentrant preparation and repeated publication are rejected. Construction failures release the reservation without publishing partial configuration. Adapter side effects on external objects are not transactional.

Configuring a typed entry does not itself mark a requested variant as applied. An adapter must verify/report its application. The report still needs transport from the app process back to XCTest; discarded or missing reports leave recorder variants unverified.

## Temporary overrides

```swift
try await withPyxis {
	$0.subscriptionStatus = "trial"
} operation: {
	try await renderPreview()
}
```

The update closure starts with a copy of the effective configuration. Nested scopes inherit the outer snapshot and can override individual entries. Sync and async overloads return the operation's result and propagate errors. Exiting an operation restores its caller's context; a throwing update does not install a scope. Passing a complete `PyxisConfiguration` instead of an update closure replaces the scope with that snapshot.

Resolution is the scoped snapshot, otherwise the prepared process default, then the key's default value. Unrelated concurrent scopes never mutate the process default or each other's dictionaries. Task-local inheritance follows Swift concurrency: structured child tasks and `Task {}` inherit a scope; `Task.detached` and arbitrary later callbacks do not. An inheriting unstructured task can retain its snapshot after the original operation returns. Explicitly pass a captured snapshot and re-enter `withPyxis(snapshot)` when retention is intended. Async overloads preserve caller isolation; custom capability values must satisfy Sendable.

Scoped configuration is not reactive UI state. UIKit/SwiftUI callbacks scheduled later do not automatically retain a temporary scope, and changing a configuration entry does not invalidate views. Apply the scope around the work that reads it, or pass a snapshot into an explicitly owned context.

`applyPyxis(to:configuration:adapters:)` explicitly applies a snapshot to a window and returns a separate window report; see [multiple windows](Windows.md).

`withPyxis` changes Pyxis reads only. It does not rerun bootstrap adapters, reset UIKit traits, restore singleton state, rewrite requested variants or claim a new bootstrap report. Tests should use scopes or local configuration values instead of repeatedly preparing global storage. Overrides in the XCTest process do not automatically reach the app process; use recorder launch configuration for that.
