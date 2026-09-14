# Applying configuration to windows

Prepare process-wide values once, then configure each window when it is created:

```swift
import PyxisRuntime

// App startup, before scene windows exist.
try preparePyxis(adapters: appAdapters)

// Scene/window creation, on the main actor.
let report = try applyPyxis(to: window)
```

`applyPyxis(to:configuration:adapters:)` defaults to the effective `pyxisConfiguration`. Supply a saved configuration explicitly to apply that snapshot. An unprepared configuration returns nil without invoking adapters or changing the window. The function is discardable and available only with UIKit from PyxisRuntime.

## Built-ins and overrides

The operation creates built-in adapters for the supplied window and applies only requested keys that have a window adapter. Built-ins cover `color_scheme`, `accessibility.content_size` and `accessibility.contrast`. They can be reapplied to the same window; omitted keys leave existing settings untouched. There is no window registry or retained window ownership.

Custom adapters take precedence over built-ins for matching keys:

```swift
let report = try applyPyxis(to: window, adapters: [
	"color_scheme": { value in
		// Configure this window using the app's own theme implementation.
		try themeController.apply(value, to: window)
		return .init(status: .applied, value: value)
	},
])
```

Custom adapters run for each application operation and should support repeated application if the caller reapplies them. Adapters execute within the supplied configuration scope, so @Pyxis reads use that snapshot even when another scope surrounds the call. A thrown adapter error becomes an unverified result; malformed result payloads throw. Earlier external side effects are not rolled back.

## Reports and multiple windows

Each result starts with the process report, replacing only keys handled in this window operation. Process-only results, unhandled results and supplemental observations remain intact. A failed window adapter replaces an earlier success for that key in the returned report; it cannot leave a stale success in that window's result.

Global storage and the prepared process report remain unchanged. Applying to a second window does not rerun process adapters and does not modify the first window's report. Transport the report for the window whose UI is being recorded. A successful application to one window makes no claim about any other window.

The current manifest stores variant results per observation, not per window or capture. An observation spanning windows with different configurations needs separate observations or a future format extension. Window configuration does not select a screenshot target. The recorder defaults to `screenshotSource: .application`; use `.screen` to include the display, including system UI such as the software keyboard. Neither option selects an individual scene window.

A withPyxis scope selects configuration; applyPyxis explicitly performs side effects on the window. Leaving the scope does not restore prior window traits. Window creation and lifecycle observation remain app-owned.

The example prepares subscription fixtures in AppDelegate and creates each scene window in SceneDelegate. Its scene manifest supports multiple windows; each scene transports its own application report.

## Verification

The example project includes a PyxisRuntimeTests unit-test target that hosts the package's runtime tests on iOS. Its package-name compiler flag permits the package's own tests to inspect package-only storage while keeping it hidden from consumers. The tests cover real UIKit windows, built-in traits, repeat application, custom precedence, per-window reports, absent preparation and release of temporary windows.
