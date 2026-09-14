# Integrating an app

Pyxis records authored UI journeys. Your app owns its state IDs, fixtures, navigation, readiness conditions and dependency overrides. Add `PyxisXCTest` to your UI test target and optionally `PyxisRuntime` to the app. Nothing runs merely because the library is linked.

## Optional bootstrap

In a debug-only launch path, call `try preparePyxis(adapters: ...)`. It reads `ProcessInfo.processInfo.environment` by default; pass `environment:` for an explicit input. Absence of `pyxisEnvironmentKey` returns nil without running callbacks or preparing storage. Malformed payloads and unknown versions throw. The request representation is package-internal.

Preparation installs the process-wide configuration once. The optional `configure:` closure sets typed configuration entries before adapters execute. Those adapters can read the staged values through `@Pyxis` or `pyxisConfiguration`. On success the configuration and report are published together. Repeated preparation throws `PyxisBootstrapError.alreadyPrepared`; recursive preparation throws `preparationInProgress`. A thrown configuration callback or invalid adapter report leaves storage unprepared, allowing a corrected retry. Already-performed adapter side effects are not rolled back.

Each `PyxisAdapter` receives one requested string and returns a `PyxisVariantResult`. It may initialize your existing subscription client or fixture provider. Adapter errors become unverified results with reasons; other adapters continue in sorted-key order. Adopting the configuration reader in app code is optional. See [configuration and scopes](Configuration.md) for typed values and temporary overrides.

After preparation, call `try applyPyxis(to: window)` whenever the app creates a window. It automatically applies the requested appearance, Dynamic Type and contrast settings, and returns a report combining process results with that window's results. Repeating it does not rerun process adapters or modify global configuration. Custom `adapters:` override built-ins for matching keys. See [multiple windows](Windows.md).

`pyxisWindowAdapters(window)` remains available for lower-level integrations. `observedPyxisAccessibility()` reports actual reduce-motion, transparency, bold-text and OS values. These helpers are available from PyxisRuntime. Window overrides do not change global simulator settings. Global color filters remain unsupported unless a consumer supplies and verifies an implementation.

Locale, language, subscriptions, eligibility, permissions, connectivity, clocks, time zones, calendars, feature flags and fixture data use consumer adapters. Device selection belongs to the CLI destination. Orientation can use `XCUIDevice.shared.orientation` in your authored test and an explicit observed report. Record the effective configuration, not just the requested configuration.

## Report transport

The app and XCTest runner are separate processes. For a window configured by Pyxis, transport the report returned by `applyPyxis(to:)`; the process preparation report does not claim that later windows were configured. For a small debug-only diagnostic element, set its accessibility identifier to `pyxis.bootstrap.report` and accessibility value to `try report.encoded()`. The UI test waits for that element, decodes its value with `PyxisBootstrapReport(encoded:)`, then passes the report to `PyxisRecorder` or calls `updateReport` before recording. The example demonstrates this transport through app-owned recorder extensions. Import `PyxisXCTest` for the recorder and report APIs, and `PyxisModel` for model declarations. Shared report/configuration APIs and `pyxisEnvironmentKey` are selectively exported; `preparePyxis` is available only after importing PyxisRuntime. A missing report is `unverified`, never assumed applied. Keep diagnostics out of release builds in real apps and never put credentials or account data in report strings.

See [recording from UI tests](UITests.md) for existing XCTestCase integration, declarative PyxisTestCase setup and async tests.

## Authored journeys

Create a `PyxisRecorder(testCase:app:configuration:)` for each test execution. Its `PyxisRecordingConfiguration` holds the project, run, domains, profile, journey identity, attempt and screenshot source. Run identity and provenance must agree across fragments merged together. The `attempt` must distinguish retries or repetitions of the same test/profile/run. Use a new run ID for a new execution. Provenance is an explicit dictionary, not an environment dump.

Before `app.launch()`, call `try recorder.configureLaunch()`. It encodes the recorder profile's requested variants into the owned application's launch environment, preserving other entries. It does not launch the app, and it rejects use after the recorder finishes. The global `pyxisEnvironmentKey` constant is also available for custom integrations.

Declare `PyxisState` values in your test project with stable, project-wide IDs. Use `capture(state, ready:)` at checkpoints and `transition(from:to:action:kind:ready:perform:)` for navigation. The source must already have a capture. Readiness closures are app-owned and should throw when unavailable; `recorder.require(element, timeout:)` provides a minimal wait. XCTest assertion failures during the action/readiness are also detected. Repeated checkpoints remain separate captures.

Use the recorder instance for readiness checks as well as captures and transitions:

```swift
try recorder.capture(home) {
	try recorder.require(app.staticTexts["home.ready"])
}
```

If bootstrap report transport needs a readiness check, create the recorder first, call `try recorder.require(reportElement)`, then supply the decoded report with `try recorder.updateReport(report)` before capturing.

The recorder retains PNG attachments and revisioned JSON fragments at checkpoints, before navigation, after navigation and on teardown. An interrupted transition is initially a failed edge, so a process interruption leaves its attempted destination visible. Successful completion updates it after destination capture. The exporter selects the latest retained revision of each observation. Teardown finalizes an unfinished recorder using XCTest failure counts. `finish` is useful for explicit status, including intentional demo failures. A crashed process may lose attachments not yet flushed by XCTest; no recorder can guarantee recovering those bytes.

Capture files are in XCTest attachments. They are exported with the macOS CLI, which resolves attachment display names within the originating test, configuration, device and repetition. Keep the xcresult for diagnosis when export fails. Paths with duplicate capture names in one execution are rejected rather than guessed.

## Timestamp models

Pass a Foundation `Date` to `PyxisRunMetadata.createdAt` and an optional `Date` to `PyxisObservation.startedAt`. Capture orchestration should supply the same run ID and creation date to every fragment in a run. The models encode ISO 8601 strings themselves, so no JSON coder date strategy is needed. For reproducible examples, supply a fixed Date rather than reading the clock independently for each fragment.
