# pyxis-swift

**Pyxis** builds a visual map of an app's screens, states and transitions. It helps developers, designers and coding agents explore large apps, discuss changes using shared screen references, and review UI variants in the [Pyxis viewer](https://pyxis.capturecontext.dev).

## Table of contents

- [Motivation](#motivation)
- [The problem](#the-problem)
- [The solution](#the-solution)
- [Usage](#usage)
  - [Building a map](#building-a-map)
  - [Recording](#recording)
  - [Dedicated and existing UI tests](#dedicated-and-existing-ui-tests)
  - [Variants](#variants)
  - [App integration](#app-integration)
- [Command-line tools](#command-line-tools)
  - [Demo](#demo)
  - [Export](#export)
  - [Configured recordings](#configured-recordings)
  - [Persistent recording stores](#persistent-recording-stores)
  - [Packaging](#packaging)
  - [Capture](#capture)
  - [Optimization](#optimization)
  - [Merging](#merging)
- [Products](#products)
- [Installation](#installation)
  - [Basic](#basic)
  - [Recommended](#recommended)
- [Troubleshooting](#troubleshooting)
- [Documentation and development](#documentation-and-development)

## Motivation

As an app grows, it becomes harder to keep track of all its screens and the ways they connect. A feature may be several steps into a flow, available only to some users, or look different depending on the app's state. Even people who work on the app every day can lose track of what is there.

A map gives the team a place to explore that UI without having to navigate through every flow manually. It is useful when joining a project, planning a feature, reviewing a design, or finding the screen where an issue occurs.

The same map can provide context for a coding agent. Screenshots show the UI, while named states and transitions give people and agents shared references for discussing it. A request such as "fix the clipped title in `notes.editor.empty` with large text" points to a specific captured state and configuration.

Pyxis is also useful for projects that have no UI tests. You can ask an agent to set it up, write the journeys needed to reach the relevant screens, and build a map. Existing UI tests make that setup more convenient, but they are not a prerequisite.

## The problem

Source code describes how an app is built, but understanding its UI from that code requires tracing navigation, state and configuration across the project. Describing a screen as "the subscription page" may be ambiguous when the app has several entry points and different states for trial, active and expired subscriptions.

Screenshots help, but a folder of images leaves their relationships implicit. Which screen does an image belong to? How do you reach it? Is this a different screen, a different state, or the same state with larger text? Those details have to be explained again whenever the images are shared with a teammate or an agent.

Design and accessibility reviews need that context too. A screen may look fine with default settings but have clipped text or overlapping controls at a larger text size. Reviewing those variants across a large app takes more than a few screenshots of its main screens.

## The solution

Pyxis keeps screenshots together with named screens, states, transitions and configuration profiles in a portable app map:

- Stable, app-owned state IDs let the team and agents refer to the same UI when discussing fixes and features.
- Recorded transitions show which actions connect captured states and how a journey moves through the app.
- Profiles keep variants such as appearance and text size associated with their captures. Reports distinguish requested settings from values the app actually applied or observed.
- The viewer lets the team explore the recorded UI and inspect variants during design and accessibility reviews.

XCTest drives the app to the states you want to include. Journeys can be written specifically to build the map, or recording can be added to existing UI tests. The recorder saves screenshots and fragments as XCTest attachments, and the CLI exports them into a folder or regular `.pyx` archive for the viewer.

Your app keeps its navigation, fixtures and configuration logic. App bootstrap adapters are optional when you need to apply variants at launch. Maps can stay local or be shared with teammates and agents, without an upload backend, accounts or telemetry.

## Usage

### Building a map

Start with the part of the app you want to understand or review. Identify its screens, the states worth capturing, and the actions that connect them. Add profiles for the variants you want to inspect, such as dark mode or larger text.

An agent can help set up Pyxis and author those journeys. For example:

> Set up Pyxis in this app and build a map of the onboarding and subscription flows. Create a UI test target if needed, give the captured states stable names, and include light, dark and large-text profiles. Export the map so we can review it and use its state IDs when discussing changes.

The map grows with the journeys you add. The [iOS example](Example/README.md) provides a starting point for the recording and app integration.

### Recording

Create a `PyxisRecorder` with your test case, application and recording configuration. The test then captures states and records the actions between them:

```swift
import Foundation
import XCTest
import PyxisModel
import PyxisXCTest

internal final class NotesJourneyTests: XCTestCase {
	@MainActor
	internal func testCreateNote() async throws {
		let app: XCUIApplication = .init()
		let home: PyxisState = .init(
			id: "notes.home",
			screenID: "notes",
			domainID: "notes",
			title: "Notes"
		)
		let editor: PyxisState = .init(
			id: "notes.editor.empty",
			screenID: "editor",
			domainID: "notes",
			title: "Editor",
			label: "Empty"
		)
		let recorder: PyxisRecorder = .init(
			testCase: self,
			app: app,
			configuration: .init(
				project: .init(id: "notes-app", title: "Notes"),
				run: .init(
					id: "local-tour-v1",
					createdAt: Date(timeIntervalSince1970: 1_789_344_000)
				),
				domains: [.init(id: "notes", title: "Notes")],
				profile: .init(id: "default", title: "Default", requested: [:]),
				journeyID: "create-note",
				title: "Create a note"
			)
		)

		defer { app.terminate() }
		try await recorder.launch(
			ready: { try await recorder.require(app.staticTexts["notes.ready"]) }
		)
		try await recorder.capture(home)
		try await recorder.transition(
			from: home,
			to: editor,
			action: "Create note",
			ready: { try await recorder.require(app.textViews["editor"]) },
			perform: { app.buttons["create"].tap() }
		)
	}
}
```

A domain groups a part of the app. A screen can have several states, such as an empty list and a populated list. A journey names an authored path through those states. Capture the source state before recording a transition; a successful transition captures its destination.

> [!NOTE]
>
> Replace the state IDs and accessibility identifiers with your app's own values. The run ID and date are illustrative. Tests and profiles that will be combined must share a run ID, creation date and provenance dictionary. Use a new run ID for each execution and distinct `attempt` values for retries. State and journey IDs should remain stable when test methods are renamed.

Recorded screenshots default to `.application`. Set `PyxisRecordingConfiguration.screenshotSource` to `.screen` to include system UI such as the software keyboard and system sheets. Failure diagnostics use the same source. The Notes example uses `.screen`.

### Dedicated and existing UI tests

For a project without UI tests, add a UI test target and write journeys for the screens you want to map. Subclass `PyxisTestCase` for tests dedicated to recording. It creates an app and recorder per test and provides hooks for launch configuration, readiness and report transport.

If the project already has UI tests, create a `PyxisRecorder` in an existing test as shown above. You can keep its assertions, actions and base class. If the app is already running, skip `launch` and start capturing; launch-time variants cannot be applied retroactively. Synchronous tests use the synchronous `capture`, `transition` and `require` overloads.

In both cases, the recorder finalizes automatically during XCTest teardown and retains screenshots and fragment revisions as attachments. A failed transition remains part of the recording.

See [UI test integration](docs/UITests.md) and the complete [async example](Example/UITests/AsyncDemoUITests.swift) for setup details.

### Variants

Profiles let you capture the same journey under different conditions for review. A recording profile describes the requested environment:

```swift
let profile: PyxisProfile = .init(
	id: "dark-large-trial",
	title: "Dark · Accessibility Large · Trial",
	requested: [
		.colorScheme(.dark),
		.accessibility(.contentSize(.accessibilityLarge)),
		.init(key: "subscription.status", value: "trial"),
	]
)
```

Built-in factories and value enums belong to `PyxisModel`; custom entries can be composed the same way. See [typed variants](docs/Models.md#typed-variant-requests). Use that profile in the recording configuration. Set `order` when one profile should open first in the viewer; the lowest value wins, with document order breaking ties. `recorder.launch()` sends its request to the app through the launch environment. For custom launch code, call `try recorder.configureLaunch()` before `app.launch()`.

### App integration

In an app-owned debug bootstrap path, call `try preparePyxis(adapters: ...)` once. Adapters apply requested values through your existing fixture, subscription, localization or dependency APIs. After creating each UIKit window, call `try applyPyxis(to: window)` to apply built-in appearance, Dynamic Type and contrast settings.

Transport the resulting report back to XCTest and provide it through the launch helper's `readReport` hook or `recorder.updateReport(_:)`. Pyxis does not impose a transport. The example uses a debug accessibility element.

> [!NOTE]
>
> Each requested variant reports whether it was applied, observed, unsupported or unverified. Missing reports stay unverified. A launch request alone does not prove that the app used it.

Device selection belongs to the simulator destination. Localization, subscription eligibility, permissions, connectivity, dates and fixture data use app-owned adapters. Global color filters need an implementation that can verify their effect.

Read [app integration](docs/Integration.md), [typed configuration and scoped overrides](docs/Configuration.md), and [multiple windows](docs/Windows.md) for the complete setup.

## Command-line tools

The `pyxis` executable provides local recording and bundle tools. Run the following commands from this package's checkout.

### Demo

The `demo` command generates a recording with synthetic screenshots. Clone this repository and run these commands from its root:

```sh
swift run pyxis demo --output .generated/demo
swift run pyxis validate .generated/demo
```

Open [the viewer](https://pyxis.capturecontext.dev) and drop the `.generated/demo` folder onto its canvas. You can also use **Library → Import folder**. No simulator is required.

For a runnable app integration, see the [iOS example](Example/README.md). It includes both existing-test and dedicated-test integrations.

### Export

The recorder saves into XCTest attachments in the `.xcresult`. It does not create a folder in your app's container.

Export an existing test result with:

```sh
swift run pyxis export \
  --xcresult /path/to/Run.xcresult \
  --output .generated/notes \
  --archive .generated/notes.pyx
```

This produces:

```text
.generated/
├── notes/
│   ├── artifact.json
│   ├── manifest.json
│   └── assets/
└── notes.pyx
```

Share the `.pyx` or import the folder directly into the viewer. One artifact includes all of its states, journeys and profiles.

### Configured recordings

For repeated recordings across devices, use a checked-in `pyxis.yaml` and one command:

```sh
swift run pyxis record --config Example/pyxis.yaml
```

The [recording configuration guide](docs/Recording.md) covers simulator selection, a full variant matrix or a selective configuration list, shared run metadata, coverage expectations and the package-plugin command. Pyxis builds once, runs authored tests on temporary simulators, and exports one compressed archive. The [SwiftUI example](Example/README.md) includes a complete configuration.

### Persistent recording stores

Use a consumer-owned filesystem directory to retain recordings across selective runs:

```yaml
storage:
  path: /Volumes/Team/Pyxis/notes
  context: development
  policy: merge
archive: false
```

Add these fields to `pyxis.yaml`. Successful runs replace matching journey/test/variant scopes and retain the others. `archive: false` skips rebuilding the archive after each run. Export when needed:

```sh
swift run pyxis store export \
  --storage /Volumes/Team/Pyxis/notes \
  --context development \
  --output notes.pyx
```

Storage may be local, a mounted filesystem, committed with ordinary Git, managed with LFS, or ignored. Pyxis does not configure Git, select branches, or delete old snapshots. See [recording stores](docs/Storage.md) for seeding, contexts, update policies, provenance, and CI use.

### Packaging

Package an existing recording without resizing its images:

```sh
swift run pyxis pack .generated/notes --output .generated/notes.pyx
swift run pyxis validate .generated/notes.pyx
```

A regular `.pyx` is a flat ZIP containing `artifact.json`, `manifest.json`, and all referenced images. Archive outputs must be new files. Raw ZIP and folder recordings are also accepted as inputs. Thin artifacts are not supported.

### Capture

For a single existing simulator, `capture` builds the app, runs its tests and exports the recording:

```sh
swift run pyxis capture \
  --project /path/to/Notes.xcodeproj \
  --scheme Notes \
  --destination 'platform=iOS Simulator,id=YOUR_DEVICE_ID' \
  --derived-data .generated/DerivedData \
  --result .generated/notes.xcresult \
  --output .generated/notes \
  --archive .generated/notes.pyx
```

Replace `--project` with `--workspace` when needed. The simulator must already exist and be available for this run. A specified result path and archive output must not already exist.

When a test fails, capture attempts to export the available recording, keeps the xcresult and log, and returns a failing exit status. Inspect both the test result and the partial recording.

### Optimization

The `optimize` command reduces image sizes before sharing a recording. With ffmpeg installed, the following command creates a separate copy whose images are at most 320 pixels wide:

```sh
swift run pyxis optimize .generated/notes \
  --output .generated/notes-320 \
  --image-width 320 \
  --archive .generated/notes-320.pyx
```

Or use the SwiftPM command plugin from the package directory:

```sh
swift package --allow-writing-to-package-directory pyxis optimize .generated/notes \
  --output .generated/notes-320 \
  --image-width 320 \
  --archive .generated/notes-320.pyx
```

The optimizer preserves aspect ratios and keeps smaller images at their original size. It updates dimensions, hashes and asset paths while retaining every state, profile, observation, capture and transition. Identical output images share storage. The source recording is unchanged.

`optimize` accepts a recording folder, manifest, regular `.pyx`, or ZIP directly. It defaults to a width of 320. The `capture`, `export` and `merge` commands also accept `--image-width`, but preserve original dimensions when it is omitted. Use `--ffmpeg /path/to/ffmpeg` if it is not on PATH.

Add `--jpeg-quality 0.5` to convert published images to JPEG with Apple ImageIO quality `0.5`. This can be combined with `--image-width`; the six-screen [SwiftUI example](Example/README.md) uses width 240 across its device, appearance, layout-direction and font-size matrix. JPEG conversion flattens transparent pixels over white and preserves every recording record.

Choose a larger width when text inspection matters. The viewer's full-size view can only show the resolution included in the artifact.

### Merging

The `merge` command combines fragments or maps from separate tests and profile runs:

```sh
swift run pyxis merge \
  --output .generated/complete \
  --archive .generated/complete.pyx \
  .generated/light .generated/dark
```

Inputs must share project and run metadata. Duplicate declarations must agree; incompatible identities produce an error. This is why run metadata should be supplied centrally before recording starts.

Publication validates each image, writes a complete staged bundle, then replaces a previous valid output. Input/output overlap is rejected. Choose your own retention and Git policy for recordings and diagnostics.

## Products

| Product | Purpose |
| --- | --- |
| `PyxisModel` | Codable models and format validation |
| `PyxisCore` | Typed configuration, scoped overrides and bootstrap transport |
| `PyxisRuntime` | Optional app bootstrap and UIKit window adapters |
| `PyxisXCTest` | Recording in existing or dedicated UI tests |
| `PyxisProcessing` | Merge, image verification, regular archives and persistent recording stores |
| `pyxis` / `PyxisPlugin` | Local command-line and SwiftPM tools |

## Installation

Use Swift 6.2 or newer. The package declares iOS 17 and macOS 14 support. The XCTest recorder and window helpers are iOS APIs; the CLI and command plugin run on macOS. Recording and exporting XCTest results require Xcode. Resizing images requires a local ffmpeg installation; JPEG conversion alone uses Apple ImageIO.

### Basic

You can add `pyxis-swift` to an Xcode project by adding it as a package dependency.

1. Open your project's package dependencies and add a package.
2. Enter [`https://github.com/capturecontext/pyxis-swift`](https://github.com/capturecontext/pyxis-swift) into the package repository URL text field and select version `0.0.1`.
3. Choose the products you need to link to your targets:

| Target | Product |
| --- | --- |
| UI tests | `PyxisXCTest` and `PyxisModel` |
| App, if it needs launch-time overrides | `PyxisRuntime` |
| Shared code that reads typed Pyxis configuration | `PyxisCore` |

### Recommended

If you use SwiftPM for your project structure, add `pyxis-swift` to your package file:

```swift
.package(
	url: "https://github.com/capturecontext/pyxis-swift.git",
	.upToNextMinor(from: "0.0.1")
)
```

Do not forget about target dependencies. For a UI test target:

```swift
.product(
	name: "PyxisXCTest",
	package: "pyxis-swift"
),
.product(
	name: "PyxisModel",
	package: "pyxis-swift"
),
```

App targets that use launch-time overrides can add `PyxisRuntime`. Linking the package alone does not change your app's behavior.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| A requested variant is unverified | Bootstrap ran, the adapter reported its result, and XCTest received the report before capturing. |
| Export finds no fragments | The test target links PyxisXCTest and actually executed recorder calls. Keep the xcresult for diagnosis. |
| Merge reports conflicting declarations | All inputs use the same run metadata and stable IDs with consistent definitions. |
| Output already exists | Archive and xcresult paths must be new. A valid recording directory can be replaced by publication. |
| ffmpeg cannot run in the plugin | Check PATH or `--ffmpeg`; use `swift run pyxis` if the plugin sandbox blocks the executable. |

## Documentation and development

See the [CLI reference](docs/CLI.md), [model guide](docs/Models.md), [processing reference](docs/Processing.md), [format contract](Format/README.md) and [verification notes](docs/Verification.md). The package owns the JSON schemas and synthetic conformance fixtures. Imported manifests never execute code or fetch asset URLs.

Run tests and refresh public API snapshots from the package root:

```sh
swift test
make swiftinterface platform=macos
make swiftinterface platform=ios
```

Snapshots live under `.agents/interfaces/<platform>/`. macOS includes all six Swift targets; iOS includes the five libraries. Tests and plugin implementation targets are excluded. The snapshots are API references; scoped exports in source remain authoritative.

The manually dispatched interface workflows can open update PRs using the automatic GitHub Actions token.

The manual [release workflow](docs/Releasing.md) bumps major, minor, or patch, records a fresh example, and publishes it as `pyxis-example.pyx` alongside the new version tag.

## License

MIT, copyright 2026 CaptureContext. See [LICENSE](LICENSE).
