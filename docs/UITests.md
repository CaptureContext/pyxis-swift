# Recording from UI tests

PyxisXCTest provides the same recorder through composition and an optional XCTestCase subclass. Both support synchronous test methods and async throwing test methods. The app's runtime integration remains optional.

## Existing test classes

Keep your existing base class and pass its test instance and XCUIApplication to PyxisRecorder. Use a PyxisRecordingConfiguration containing project, shared run metadata, domains, profile and optional journey identity/title. Omitted journey identity and title default to XCTest's test name. Supply explicit IDs if they must survive test renaming. A run must use consistent ID, timestamp and provenance across tests; attempts distinguish retries.

Create the recorder before recording checkpoints. If the app is already running, skip launch configuration and optionally supply its observed report. Launch-time variants cannot be retroactively applied by the recorder.

For an app you want to launch, either call configureLaunch then launch it yourself, or use the optional shared async lifecycle:

```swift
let recorder = PyxisRecorder(
	testCase: self,
	app: app,
	configuration: configuration
)
try await recorder.launch(
	configure: { app in
		app.launchArguments.append("--fixture")
	},
	ready: { try await recorder.require(app.staticTexts["home.ready"]) },
	readReport: { try await readAppReport() }
)

try await recorder.capture(home)
XCTAssertTrue(app.buttons["create"].exists)
```

The launch helper does not terminate the app afterward; ownership remains with the caller. It preserves unrelated launch environment entries. Missing report transport leaves requested variants unverified. No report accessibility identifier is built into the library.

## Dedicated tests

Subclass PyxisTestCase and override recordingConfiguration. An app-owned intermediate base class can provide common project/run/domain data and readiness/report transport. Setup creates a new app and recorder for each test execution, invokes recorder.launch with the hooks below, and registers cleanup. Teardown finalizes the recorder before terminating the app. No recorder or app is shared between tests.

Available main-actor hooks:

- makeRecordingConfiguration() throws validates dynamic inputs such as run metadata. Its default implementation reads recordingConfiguration.
- makeApplication() selects the application, defaulting to XCUIApplication().
- configureApplication(_:) async throws runs before launch configuration and launch.
- waitUntilReady() async throws provides app-specific readiness.
- readBootstrapReport() async throws returns an optional report using the app's chosen transport.

The app and recorder properties are available after setup creates them. Access before that point is a programming error. Prefer these hooks over overriding XCTest setup; if overriding setup, call super. An omitted recordingConfiguration throws during setup rather than silently omitting recording.

```swift
internal final class NotesJourneyTests: AppPyxisTestCase {
	@MainActor
	internal func testCreateNote() async throws {
		try await recorder.capture(notesList)
		try await recorder.transition(
			from: notesList,
			to: editor,
			action: "Create note",
			ready: { try await self.recorder.require(self.app.textViews["editor"]) },
			perform: { self.app.buttons["create"].tap() }
		)
	}
}
```

AppPyxisTestCase and the states above belong to the consuming app. Example/UITests/AsyncDemoUITests.swift provides a complete concrete implementation; DemoUITests.swift demonstrates an existing XCTestCase subclass.

## Screenshot source

`PyxisRecordingConfiguration.screenshotSource` defaults to `.application`. Set it to `.screen` when a state includes system UI such as the software keyboard. Captures and failure diagnostics use the same source. This records the display rather than selecting a particular scene window.

## Async behavior and failures

capture and transition accept main-actor async throwing closures in async tests. Synchronous overloads remain available to synchronous tests. Async require uses a Duration timeout, defaulting to five seconds. The lower-level AsyncXCUIAutomation product offers cancellable existence, nonexistence, typed-property, predicate and app-state waits with Duration timeouts. Import AsyncXCUIAutomation explicitly to use its extensions.

The polling task suspends between accessibility probes. Apple UI actions and each probe remain synchronous on the main actor. Cancellation cannot interrupt a synchronous Apple framework operation already underway. Async recording checks cancellation around caller closures and preserves failure fragments; an interrupted transition remains failed and retains its source capture.

Operations on one recorder are sequential. Overlapping capture, transition or launch calls throw recordingInProgress, as do configureLaunch, updateReport and finish while such an operation is suspended. Readiness queries remain usable inside those operations. Await child recording tasks before the test returns.

Teardown finalizes unfinished observations using XCTest failures, while preserving failures already recorded by Pyxis. A skipped test is incomplete unless a recording failure already occurred. Explicit finish is still available and does not override a known failure. XCTest assertion failures during ready/perform are detected even if they do not throw. A caught recording failure can therefore produce a failed observation in an otherwise passing XCTest test.

The package resolves swift-async-xcuiautomation from its tagged GitHub release. Neither library requires swift-dependencies or a new application architecture.

The recorder exposes its recorded application as a read-only `app` reference. App-owned recorder extensions can use it for readiness checks and report transport without accepting a second app argument. See the [example recorder extensions](../Example/UITests/Support/PyxisRecorder+Example.swift).
