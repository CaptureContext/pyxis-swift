# Notes example

A six-screen SwiftUI app demonstrates Pyxis recording without adopting a new application architecture. UIKit app and scene delegates handle bootstrap and window configuration; SwiftUI owns the screens and their local state.

| Screen | What it demonstrates |
| --- | --- |
| Home | Recent notes, navigation and a text-heavy introduction |
| Note | Long-form text with Dynamic Type |
| Notebooks | Grouped content and a toolbar action |
| New note | A modal form with validation and save/cancel actions |
| Settings | Toggles and account navigation |
| Notes Plus | A subscription fixture, with no real purchases |

The app uses synthetic data and keeps edits in memory. It imports the package at `..` and uses no Myo files or data.

## Record the full matrix

Use Swift 6.2 or newer. Install Xcode, XcodeGen and ffmpeg, then run from the package root:

```sh
make -C Example project
swift package --disable-sandbox --allow-writing-to-package-directory \
  pyxis record --config Example/pyxis.yaml --list
swift package --disable-sandbox --allow-writing-to-package-directory \
  pyxis record --config Example/pyxis.yaml
```

The Swift runner reads [pyxis.yaml](pyxis.yaml) and creates an isolated simulator for each device, builds once, runs all eight UI combinations on each device, and exports one combined `recording.pyx` under `.generated/recordings/<run-id>/`. It deletes its simulators afterward. It does not use or alter an existing personal simulator.

| Dimension | Values |
| --- | --- |
| Device | iPhone 18 Pro, iPhone SE 2, iPhone Duo when installed |
| Appearance | Dark, light |
| Layout direction | LTR, RTL |
| Dynamic Type | Large, xxxLarge |

Large and xxxLarge map to `large` and `xxx_large` in the manifest. RTL changes the layout independently of language; the example uses English text in both directions. Subscription status stays fixed at `trial`.

The runner chooses the newest installed compatible iOS runtime for each device. Missing iPhone 18 Pro or SE support is an error. Duo is optional: an unavailable device or runtime is reported in `plan.json` instead of being silently substituted. Two available devices produce 16 profiles; all three produce 24.

The SE label resolves to the actual second-generation simulator. Edit `devices` in `pyxis.yaml` to choose a subset, or set a device's `runtime` to an installed version such as `27.0`. Change `output` to select another output root. All paths are relative to the configuration file.

Use `--skip-build` only when reusing unchanged test products. The `derived_data` field selects the build cache. SwiftPM's explicit `--disable-sandbox` option is needed for Xcode and CoreSimulator access; the plugin never bypasses its sandbox automatically. The equivalent standalone command is `swift run pyxis record --config Example/pyxis.yaml`.

For selective recordings, replace the `variants` object with a list of concrete configurations. Only those entries run. The full matrix remains the example default.

See [configuration-driven recording](../docs/Recording.md) for the generic schema, supported Xcode options, run metadata and plugin permissions. The configuration contains no application navigation.

The initial viewer profile is **iPhone 18 Pro / Dark / LTR / Large**. Manual Xcode tests also default to Dark / LTR / Large on the selected simulator.

Every profile traverses all six screens in two journeys. **Make room for a new idea** reads a note, clears the notebook, opens an empty editor, types with the keyboard visible and saves. **Personalize Notes** opens Settings and Notes Plus. Notes is the first domain and Settings is the second. The eight recorded states include empty notebooks, an empty editor and a keyboard-visible editor. Tests compare requested variants against the app's bootstrap report and verify the actual SwiftUI appearance, layout direction and Dynamic Type size on every screen, including the modal editor. `coverage.json` also checks all device/profile/state combinations, observation status and variant reports. Failed runs retain their XCTest results and available recordings and return a nonzero status.

## Keep recordings between runs

The example updates `.generated/ExampleRecordingStore` in the `example` context. This is the example's local storage choice; consumer projects can use any filesystem location and Git policy. Set `archive: false` when iterating to update the store without repacking it. Export on demand from the package root:

```sh
swift run pyxis store export --storage .generated/ExampleRecordingStore --context example --output .generated/example.pyx
```

With storage enabled, `recording.pyx` contains the complete retained context. The run's `bundle/` contains only that invocation's recordings. Selective runs keep the other scopes when using the default merge policy.

## Small sharing artifacts

Matrix exports use these publication options before creating the ZIP:

```sh
--image-width 240 --jpeg-quality 0.5
```

ffmpeg resizes each screenshot without changing its aspect ratio or enlarging smaller images. Apple's ImageIO encoder converts it to JPEG at quality `0.5` on its `0...1` scale. Transparent pixels are composited over white. All states, captures, transitions and profile metadata remain intact.

The recording configuration uses `screenshotSource: .screen` to include the software keyboard. The keyboard state also waits until the keyboard is hittable; an app-only screenshot can omit this separate system window.

The original full-resolution XCTest attachments remain in each device's `Tests.xcresult`; only the published images are reduced. Device bundles are merged without recompressing them. Import the single `recording.pyx` into the [Pyxis viewer](https://pyxis.capturecontext.dev).

To publish an existing recording with the same settings:

```sh
swift run pyxis optimize .generated/existing-recording \
  --output .generated/compact-recording \
  --image-width 240 --jpeg-quality 0.5 \
  --archive .generated/compact-recording.pyx
```

Archive output paths must be new. `optimize` accepts recording folders, manifests, `.pyx`, and ZIP inputs directly. No extraction step is required. The recording command already applies `images.width` and `images.jpeg_quality` from YAML before creating its artifact. This example ignores generated recordings, results and build caches; your project can choose its own policy.

## Typed example declarations

`ExampleProfile` reuses the public `PyxisVariantEntry.ColorScheme`, `LayoutDirection` and `Accessibility.ContentSize` types. The default is `.dark`, `.ltr`, `.large`; raw values are encoded only when building the recording profile or reading the runner environment.

```swift
let profile: ExampleProfile = .init(
	colorScheme: .dark,
	direction: .ltr,
	contentSize: .large
)
```

The ordinary test helper accepts the same options, for example `launch(colorScheme: .dark, contentSize: .large, journey: .tour)`. `ExampleJourney` keeps each journey's stable ID and title together. Invalid or missing variant values in a runner payload throw before launch; no payload uses the manual defaults.

The app uses literal accessibility identifiers such as `"open.detail"`. UI tests independently declare `ExampleElement` and `ExampleScreen` and query `app.buttons[.openDetail]`. No app source or fixture is compiled into the UI-test target. Pyxis owns the built-in variant keys and the CLI environment contract. App-specific subscription and test-control declarations stay in the example. `ExampleTestEnvironmentKey` contains only `EXAMPLE_*` verification flags; the device handoff uses `PyxisRecordingEnvironment.Key` constants. `SIMULATOR_MODEL_IDENTIFIER` is an Apple-provided environment value.

`ExampleProfileTests` checks profile encoding, all eight variant combinations, default ordering, invalid values and stable identifiers. The normal YAML recording still selects only the two matrix journeys.

## Workspace and local package

Open `PyxisExample.xcworkspace`. It contains the Xcode project and the local package in this directory. XcodeGen marks that package `excludeFromProject`; package resolution belongs to the workspace. The Xcode project contains only app/scene delegate entry shims, bundle metadata and tests.

`Package.swift` owns the dependency on the parent Pyxis checkout. [ExampleApp](Sources/ExampleApp/README.md) contains all application implementation. [ExampleTesting](Sources/ExampleTesting/README.md) only re-exports the test dependencies and is linked solely into UI tests. There is no shared-source folder and the app never links XCTest.

Run `make -C Example project` after changing `project.yml`. The project and workspace are checked in, and the Make target regenerates both deterministically.

## Integration structure

- `Sources/ExampleApp/ExampleApplicationDelegate.swift` calls `preparePyxis` once and supplies the subscription fixture and verified readable device name. Tests forward the resolved model and label through `configureExampleDevice()`; the app checks the actual simulator model before reporting that label.
- `Sources/ExampleApp/ExampleSceneDelegate.swift` calls `applyPyxis(to:)` for each window and configures the SwiftUI layout direction.
- `Sources/ExampleApp/BootstrapReportView.swift` exposes that window's report through an accessibility element. It reads SwiftUI environment values to report the rendered traits. Bootstrap and this diagnostic are compiled only in debug builds.
- `Sources/ExampleApp/Views/` contains the six screens and their navigation root.
- `UITests/MatrixUITests.swift` adds async recording to an ordinary `XCTestCase` across two journeys, repeated by Xcode for each configured profile.
- `UITests/AsyncDemoUITests.swift` demonstrates dedicated recording through `PyxisTestCase` and its launch hooks.
- `UITests/DemoUITests.swift` retains synchronous recording and failure examples.
- `UITests/Support/` owns the test profiles, identifiers, journeys and fixtures. `PyxisRecordingEnvironment`, re-exported by `PyxisXCTest`, decodes CLI values and supplies typed dates, profile order and variants.
- `UITests/Support/` extends `PyxisState`, `PyxisDomain`, `PyxisRecordingConfiguration` and `PyxisRecorder` with app-owned declarations and helpers. Calls read `recorder.capture(.home)` and `recorder.transition(from: .editorEmpty, to: .editorKeyboard, ...)`.

The runner supplies `PYXIS_VARIANTS`, `PYXIS_PROFILE_ORDER`, shared run metadata and resolved device details to the tests. One run ID and creation date are shared across all devices. Manual Xcode runs use fixed demonstration metadata; use the runner for a fresh, shareable execution. The scene manifest supports multiple windows, and report transport stays window-specific.

The Xcode project is checked in. Install XcodeGen and regenerate it after changing `project.yml` or adding source files:

```sh
xcodegen generate --spec Example/project.yml
```

## Failure examples

The matrix excludes intentional failure fixtures. The ordinary demo tests retain a caught transition error and a caught cancellation, both of which pass XCTest while preserving a failed Pyxis observation.

Two additional failure checks are skipped by default. Opt in to the synchronous assertion check:

```sh
TEST_RUNNER_EXAMPLE_VERIFY_ASSERTION_FAILURE=1 swift run pyxis capture \
  --workspace Example/PyxisExample.xcworkspace --scheme PyxisExample \
  --destination 'platform=iOS Simulator,id=YOUR_DEVICE_ID' \
  --only-testing PyxisExampleUITests/DemoUITests/testNonthrowingAssertionFailure \
  --result .generated/assertion-failure.xcresult --output .generated/assertion-failure-map
```

The command must fail while retaining a valid partial recording. For the uncaught async-error check, use `TEST_RUNNER_EXAMPLE_VERIFY_ASYNC_FAILURE=1` and select `PyxisExampleUITests/AsyncDemoUITests/testAsyncThrownFailure`.

For a simulator-free synthetic recording, run `swift run pyxis demo --output .generated/demo`. Those drawn images are separate from this SwiftUI app.
