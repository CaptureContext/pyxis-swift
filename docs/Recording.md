# Recording with YAML

`pyxis record` builds your authored UI tests once, runs the selected configurations on isolated iOS simulators, and produces one shareable archive. Your tests own navigation, fixtures and assertions. YAML selects the devices and variant values passed to those tests.

From a package checkout:

```sh
swift run pyxis record --config /path/to/app/pyxis.yaml --list
swift run pyxis record --config /path/to/app/pyxis.yaml
```

From a Swift package that depends on Pyxis:

```sh
swift package --disable-sandbox --allow-writing-to-package-directory \
  pyxis record --config pyxis.yaml
```

Recording needs Xcode and an installed simulator runtime. SwiftPM's plugin sandbox can hide CoreSimulator and block Xcode's writes outside the package. The explicit `--disable-sandbox` flag permits that access for a trusted local recording configuration. The plugin does not disable its sandbox automatically. Export, validation and optimization can use the normal sandbox with appropriate output-directory permissions.

## Full matrix

The default filename is `pyxis.yaml`. Keys use lower snake case. Paths resolve relative to the configuration file. YAML is parsed by Yams; JSON syntax also works. No Python or shell runner is required.

```yaml
version: 1
xcode:
  project: App.xcodeproj
  scheme: App
  only_testing: [AppUITests/RecordingTests]
  build_arguments: [CODE_SIGNING_ALLOWED=NO]
  test_arguments: [-testLanguage, en, -testRegion, US]
  environment:
    APP_FIXTURE: demo
devices:
  - name: iPhone 18 Pro
  - name: iPhone SE 2
    simulator: iPhone SE (2nd generation)
    runtime: '27.0'
  - name: iPhone Duo
    optional: true
variants:
  color_scheme: [dark, light]
  layout_direction: [ltr, rtl]
  accessibility.content_size: [large, xxx_large]
output: .generated/recordings
derived_data: .generated/RecordingDerivedData
images:
  width: 240
  jpeg_quality: 0.5
coverage:
  states: [home, detail]
```

An object under `variants` means a Cartesian product. Every dimension contains an array of unique string values. The first value of each dimension, on the first available device, is the first profile. Set `PyxisProfile.order` from `PYXIS_PROFILE_ORDER` so viewers retain this default after publication. Use `variants: {}` for one configuration per device without additional overrides.

`device` is an optional variant dimension. When omitted, the matrix uses every declared available device. When present, its values must match `devices[].name`.

## Selective configurations

Use an array under the same `variants` key to record only the listed configurations:

```yaml
variants:
  - device: iPhone 18 Pro
    color_scheme: dark
    layout_direction: ltr
    accessibility.content_size: large
  - device: iPhone SE 2
    color_scheme: dark
    layout_direction: ltr
    accessibility.content_size: large
  - device: iPhone 18 Pro
    color_scheme: light
    layout_direction: ltr
    accessibility.content_size: large
  - device: iPhone SE 2
    color_scheme: dark
    layout_direction: rtl
    accessibility.content_size: large
```

Each entry maps variant keys to individual string values. There is no additional cross product between entries. Omitting `device` repeats that entry on every declared available device. Omitting another property leaves it for your test/app defaults; it does not expand that property. YAML anchors and merge keys can share repeated values.

List order determines profile order. Duplicate or overlapping configurations are errors. Empty lists, empty dimension arrays and unknown device names are errors too. There is no `exclude` syntax.

The runner only boots devices needed by the selected configurations and only executes those configurations. Coverage checks the selected set, so intentionally absent combinations do not fail recording. The viewer still lets users select absent combinations and labels them as unrecorded.

## Options

- `version`, `xcode`, `devices`, `variants` and `output` are required. Provide exactly one `xcode.project` or `xcode.workspace`, a scheme, and a nonempty `only_testing` list of XCTest selectors.
- Device `name` is the profile's readable label. Optional `simulator` supplies the installed device-type name or identifier when it differs. Otherwise `name` is used for resolution. Names must be unique. Pyxis chooses the newest installed compatible iOS runtime, or the requested version/identifier. Missing selected required devices fail before building. Skipped optional devices appear in `plan.json`.
- `build_arguments` and `test_arguments` are literal `xcodebuild` arguments. There is no shell interpolation. Pyxis owns destinations, result paths, test selectors and test configurations. Generate your Xcode project first when your app requires it.
- `environment` sets app-owned test-runner variables. Forward values to `app.launchEnvironment` in tests when the app needs them. `PYXIS_` names are reserved.
- `derived_data` selects a reusable build cache. Without it, each run gets its own cache. `--skip-build` requires this field and unchanged products. Omit the flag after changing code, dependencies, scheme settings or toolchains.
- The runner reads the `.xctestrun` generated by `build-for-testing` and creates a named Xcode test configuration per selected variant. Authored journeys are reused across configurations. Existing test settings and built product paths are preserved. Use one enabled configuration in the source Xcode test plan. If cached products contain multiple candidate files, `xcode.test_run` can name the intended `.xctestrun` explicitly.
- `images.width` is a maximum width in pixels. It never upscales and requires ffmpeg on PATH or at `images.ffmpeg`. `jpeg_quality` uses Apple's ImageIO encoder at a quality in `0...1`; omit it to preserve the image format. JPEG conversion alone does not require ffmpeg.
- `coverage.states` optionally requires these states across passed journeys for every selected configuration. Selected configurations must produce passed observations with verified variant values even when `coverage` is omitted. Failed observations always make the command fail.

## Read the configuration in tests

Every test configuration receives these values in `ProcessInfo.processInfo.environment`:

| Variable | Value |
| --- | --- |
| `PYXIS_VARIANTS` | JSON object containing one selected configuration, including its readable `device` value |
| `PYXIS_PROFILE_ORDER` | Nonnegative position in the resolved recording plan |
| `PYXIS_RUN_ID` | One generated ID shared by the entire execution |
| `PYXIS_RUN_TIMESTAMP` | Shared creation time as Unix seconds |
| `PYXIS_DEVICE_NAME` | The configured device label |
| `PYXIS_DEVICE_MODEL` | Resolved hardware identifier for diagnostics or verification |

`PyxisRecordingEnvironment` decodes and validates this contract. It lives in `PyxisCore` so the CLI and XCTest use the same implementation, and `PyxisXCTest` re-exports it. Missing values remain `nil` for manual-run defaults; malformed supplied values throw. `encoded()` emits only the Pyxis-owned fields. Pass its values to your profile and run metadata:

```swift
import Foundation
import XCTest
import PyxisXCTest
import PyxisModel

let environment: PyxisRecordingEnvironment = try .init(environment: ProcessInfo.processInfo.environment)
let requested: PyxisVariants = try XCTUnwrap(environment.variants)
let run: PyxisRunMetadata = try .init(
	id: XCTUnwrap(environment.runID),
	createdAt: XCTUnwrap(environment.runCreatedAt)
)
let encoder: JSONEncoder = .init()
encoder.outputFormatting = [.sortedKeys]
let profile: PyxisProfile = try .init(
	id: String(decoding: encoder.encode(requested), as: UTF8.self),
	title: "Recording configuration",
	requested: requested,
	order: XCTUnwrap(environment.profileOrder)
)
```

The sorted JSON object supplies a stable profile ID without delimiter ambiguity. [ExampleProfile](../Example/UITests/Support/ExampleProfile.swift) uses PyxisModel color-scheme, layout-direction and font-size types. [Its recording extension](../Example/UITests/Support/ExampleProfile+Recording.swift) decodes the runner environment and supplies defaults for ordinary Xcode runs. [The recording configuration extension](../Example/UITests/Support/PyxisRecordingConfiguration+Example.swift) supplies shared project, domain and run metadata.

Pyxis passes requested variants to the app during recorder launch. Your bootstrap adapters should report what was actually applied or observed. In particular, a device adapter should verify the actual simulator and translate it to the same readable label. Returning the requested label without verification can conceal an incorrect recording.

## Output and failures

Each invocation creates `<output>/<run-id>/` for results and diagnostics. Unless `archive: false`, it also creates `recording.pyx` for the viewer. When `storage` is configured, a successful run updates that store and the archive exports the resulting complete context, including retained recordings. The directory also contains:

- `bundle/`, the merged recording with optimized images.
- `plan.json`, the resolved devices, ordered selections and skipped optional devices.
- `coverage.json` and `failures.json` with diagnostics.
- `build.log` and per-device folders with `Recording.xctestrun`, `Tests.xcresult`, logs and exported bundles.

Image optimization happens during export, before ZIP creation. Original screenshots remain in XCTest results. The final merge does not recompress images.

Pyxis creates and deletes only its own temporary simulators. Boot, test and export failures still trigger cleanup. Ctrl-C cancels the active command, stops further device runs and attempts simulator cleanup before exiting. Failed runs retain diagnostics and publish available captures when possible, return a nonzero status, and report the available recording as partial. Failed invocations with storage configured do not advance the store or export its context. A forcibly terminated process may leave its simulator behind; its name includes the run ID.

The example ignores generated output. Consumers independently choose Git, LFS, ignored files, or external persistence for their recording store. Pyxis does not modify Git configuration or upload recordings. See [the example YAML](../Example/pyxis.yaml) and [its two journeys](../Example/UITests/MatrixUITests.swift) for the complete implementation.

## Update a persistent recording store

```yaml
storage:
  path: /Volumes/Recordings/notes
  context: development
  policy: merge
archive: false
```

`storage` is optional. Its path can be absolute or relative to the YAML file. `context` defaults to `default`; `policy` defaults to `merge`. `archive` defaults to true. With `archive: false`, record updates the store without packaging its assets. Export a regular `.pyx` later with `pyxis store export`.

Only runs whose tests and configured coverage checks succeed advance the store. Failed runs leave the last successful store snapshot unchanged and retain per-run diagnostics and any exported captures. `storage-result.json` records the updated context and snapshot ID. Store publication can succeed even if subsequent archive export fails; retry export without rerecording.

Coverage is evaluated against this invocation's selected variants. When selecting only some tests, configure `coverage.states` for the states those tests are intended to capture. A successful partial selection replaces the matching journey/test/requested-variant scopes; unselected scopes survive `merge`.

Choose an explicit context when branches should be isolated; Pyxis does not inspect Git or decide when old recordings are stale. Retained captures carry their original run provenance. The complete storage guide is [Storage.md](Storage.md).
