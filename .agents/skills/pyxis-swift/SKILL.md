---
name: pyxis-swift
description: Record and export iOS app journeys with Pyxis Swift.
license: MIT
---

# Pyxis Swift

Use Pyxis to capture named app states, their transitions and UI variants. Keep navigation, fixtures and readiness checks in the consuming app's tests.

Resolve the consuming project's dependencies, then locate its selected `pyxis-swift` checkout. Common locations are `.build/checkouts/pyxis-swift` for SwiftPM and `SourcePackages/checkouts/pyxis-swift` under Xcode's configured package directory. Respect local dependency overrides and custom checkout locations. Use the revision selected by the project.

Interfaces and documentation belong to the package and are not bundled with this skill. All package paths below are relative to that resolved checkout. Read exact APIs from `.agents/interfaces/<platform>/`; use `ios/` for the recorder and UIKit runtime helpers because their macOS snapshots omit iOS-only declarations. If an interface is absent, inspect the corresponding source at the same revision.

## Choose the integration

| Consumer | Products |
| --- | --- |
| UI test target | `PyxisXCTest` and `PyxisModel` |
| Optional app bootstrap | `PyxisRuntime` |
| Shared typed configuration | `PyxisCore` |
| Custom bundle processing | `PyxisProcessing` and `PyxisModel` |

Add `https://github.com/capturecontext/pyxis-swift` as a package dependency. See its `README.md` for product setup. App targets do not need XCTest or a new dependency architecture. Import `PyxisModel` explicitly when declaring model types; scoped exports do not expose every underlying module.

## Record journeys

For existing UI tests, create a `PyxisRecorder(testCase:app:configuration:)` and retain the test's base class, assertions and actions. For dedicated recording tests, subclass `PyxisTestCase`. Supply `recordingConfiguration` or override `makeRecordingConfiguration()` when configuration can throw. Use `waitUntilReady()` and `readBootstrapReport()` for app-owned launch hooks.

- Run recorder operations on the main actor, sequentially. Await each async operation before starting another or returning from the test.
- Use `recorder.launch(...)` for the async launch lifecycle. For custom or synchronous launches, call `recorder.configureLaunch()` before `app.launch()`.
- An already-running app can be recorded directly. Launch-time variants require a new configured launch.
- Set `PyxisRecordingConfiguration.screenshotSource` to `.screen` when recording system UI such as the keyboard; `.application` is the default.
- Use `recorder.require(...)` for readiness. Capture the source state before calling `transition(from:to:action:ready:perform:)`; a successful transition captures its destination.
- XCTest teardown finalizes the recorder. Failed transitions and failed observations remain evidence. The generic recorder leaves app termination to its caller; `PyxisTestCase` handles it during teardown.

Read `docs/UITests.md` for lifecycle hooks and failure behavior. Use the async example in `Example/UITests/AsyncDemoUITests.swift` or existing-test example in `Example/UITests/DemoUITests.swift` when writing a complete integration.

## Model states and runs

Give domains, states and journeys stable app-owned IDs. Use a state for a semantic UI condition and a profile for its requested environment. Titles and image hashes do not define state identity. Repeated captures may have identical pixels while representing distinct observations or checkpoints.

Tests and profiles that will be merged must share project metadata and the same `PyxisRunMetadata` ID, creation date and provenance. Generate that metadata once per execution and pass it to each test. Use distinct `attempt` values for retries. Duplicate declarations must agree.

Use `Date` for run and observation timestamps; the models encode ISO 8601 themselves. Use Pyxis's models and JSON utilities instead of hand-building manifests. Wire keys and Pyxis-owned tokens use lower snake case, with dots separating variant namespaces. Preserve app-owned IDs, dictionary values and other free-form strings exactly. See the format contract in `Format/README.md` for validation and variant vocabulary.

## Apply variants in the app

Call `try preparePyxis(adapters: ...)` once in an app-owned debug bootstrap path. It reads the launch environment by default and does nothing when there is no Pyxis payload. Do not call it repeatedly to configure windows or reset tests.

Call `try applyPyxis(to: window)` when each UIKit window is created. Built-in window adapters handle appearance, Dynamic Type and contrast. Device selection belongs to the simulator destination; localization, subscriptions, permissions and fixtures need app-owned configuration. Window traits do not change global simulator accessibility settings.

Transport the report for the recorded window back to XCTest through `readReport`, `readBootstrapReport()` or `recorder.updateReport(_:)`. Requested values alone do not establish that a variant was applied. Missing reports remain unverified; Pyxis does not provide an automatic cross-process transport.

Use `withPyxis` for scoped configuration reads. It does not rerun adapters, undo window changes or propagate overrides from the test process into the app. Read `docs/Integration.md`, `docs/Configuration.md` or `docs/Windows.md` when that behavior is relevant.

## Configure recordings

Use `pyxis record --config pyxis.yaml --list` to inspect the plan, then omit `--list` to record. Under `variants`, an object of arrays defines a full matrix; an array of value dictionaries selects specific configurations. Tests still own navigation. The runner supplies shared run metadata and profile ordering, applies configured image optimization, and exports one regular archive unless `archive: false`. Read `docs/Recording.md` and `Example/pyxis.yaml` for required fields, device resolution and plugin permissions.

## Publish a shareable recording

Screenshots and fragments are XCTest attachments in the `.xcresult`. From the package checkout, export and validate them:

```sh
swift run pyxis export --xcresult /path/to/Run.xcresult \
  --output .generated/recording --archive .generated/recording.pyx
swift run pyxis validate .generated/recording
```

Use `merge --output ... --archive ...` to combine tests and profiles into one artifact. For programmatic publication, use `BundlePublisher`; `MapMerger` alone does not publish image assets.

To reduce storage before sharing, use `optimize` with a separate output directory and `--image-width 320`, or provide that option during export, merge or capture. Resizing requires ffmpeg. Existing `.pyx` and ZIP inputs can be optimized directly. Preserve every recording record; only image data and its descriptors change.

Let the consumer choose whether to track recordings in Git, use LFS, ignore them, or keep them outside the repository. Pyxis does not change Git configuration. Archive output paths must be new and outside the input/output directories. Keep failed test results and report partial coverage honestly. Publishing a bundle does not establish that all intended app states were recorded.

Use `pack INPUT --output recording.pyx` to package an existing bundle. A regular `.pyx` has root `artifact.json`, `manifest.json`, and referenced assets. Thin artifacts are not supported yet.

For selective recordings, configure a persistent `storage.path` and explicit `storage.context` in recording YAML. Successful runs merge matching journey/test/requested-variant scopes, retaining other scopes and their original run metadata. Set `archive: false` to avoid repacking after every run; use `store export --storage PATH --context NAME --output recording.pyx` when needed. `policy: update` replaces the complete context instead. Read `docs/Storage.md` for snapshot retention, concurrency, and plugin permissions.

Read the CLI reference in `docs/CLI.md` for capture, plugin permissions and optimization options, or the processing reference in `docs/Processing.md` for custom tooling. Imported asset paths must stay inside the bundle; never fetch asset URLs or execute imported content.

## License

This skill is distributed under the [MIT license](licenses/LICENSE).

## Typed requests and runner environment

Use `PyxisVariants` with entries such as `.colorScheme(.dark)` and `.accessibility(.contentSize(.xxxLarge))`. Built-in value enums and key constants live in `PyxisModel`; extend `PyxisVariantEntry` for app-owned variants. Requests encode as a JSON object with `color_scheme`, `layout_direction`, and namespaced accessibility keys. Use `PyxisRecordingEnvironment(environment:)`, exported by `PyxisXCTest`, to decode CLI variants, shared run metadata, device labels and profile order instead of duplicating environment parsing.
