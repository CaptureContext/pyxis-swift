# Local CLI

Run `swift run pyxis --help` from the package directory. Swift Argument Parser generates command help; use `swift run pyxis capture --help` or `swift run pyxis help capture` for a specific command. Invalid or empty arguments fail during parsing before capture starts any Xcode process. The executable runs on macOS with Xcode installed for capture/export. Validation, merge and synthetic generation do not require an active simulator.

```sh
swift run pyxis demo --output .generated/demo
swift run pyxis validate .generated/demo
swift run pyxis merge --output .generated/merged first-fragment second-fragment
swift run pyxis export --xcresult .generated/run.xcresult --output .generated/map
swift run pyxis capture --workspace Example/PyxisExample.xcworkspace \
  --scheme PyxisExample --destination 'platform=iOS Simulator,id=YOUR_DEVICE_ID' \
  --derived-data .generated/DerivedData --result .generated/run.xcresult \
  --output .generated/map
```

Validation and merge also accept `.pyx` and ZIP inputs directly. A directory input contains `manifest.json`; a manifest input resolves assets relative to its parent. Merge accepts fragments or published maps that share a project/run and whose duplicate declarations agree. Publication verifies all input images, then stages the new bundle before replacing the output. Existing valid output survives a failed validation/publication. Do not use the same directory as a raw input and a generated output when you need to retain raw data.

Capture accepts exactly one `--project` or `--workspace`, plus `--scheme`, explicit `--destination` and `--output`. Optional `--only-testing` narrows to one XCTest selector; `--derived-data` isolates build products. The CLI passes arguments directly to `Process`. The `capture` command does not create, shut down or delete simulators. XCTest parallel execution is disabled for a capture run. The consumer must ensure another process is not driving the same device.

A custom `--result` must not already exist. Otherwise a unique sibling xcresult is chosen. Logs use `<result>.xcresult.log` and an existing log is never overwritten. The CLI retains both on test failure and attempts to publish available fragments. A failed test run still returns nonzero after successful partial publication. Missing fragments or export failures report an error and leave existing output intact. The export reader follows the attachment manifest emitted by Xcode's `xcresulttool export attachments`, verified against its locally available JSON schema and a real UI test result. The reader removes xcresulttool's generated index/UUID filename suffix before matching recorder names. Xcode format changes can require an exporter update.

## Record from configuration

Use `swift run pyxis record --config Example/pyxis.yaml --list` to inspect the Notes example's device plan, then omit `--list` to build and record it. `record` creates temporary simulators, runs the configured authored tests on each device, exports optimized images, and merges them into one archive. The versioned YAML file selects the Xcode container, scheme, tests, devices, variant matrix or explicit configuration list, publication settings and optional coverage expectations.

See [configuration-driven recording](Recording.md) for the configuration guide and test-runner metadata contract. The same command works through the plugin with explicit Xcode/CoreSimulator access:

```sh
swift package --disable-sandbox --allow-writing-to-package-directory \
  pyxis record --config Example/pyxis.yaml
```

## Package command plugin

```sh
swift package --allow-writing-to-package-directory pyxis demo --output .generated/demo
```

The plugin forwards arguments to the same executable. SwiftPM requires permission for package-directory writes. Outputs elsewhere require the corresponding `--allow-writing-to-directory` permission. Simulator and Xcode access can be blocked by the plugin sandbox, so use `swift run pyxis capture ...` or the built executable for capture. The plugin never bypasses sandbox permissions itself.

The output directory is a portable regular bundle containing `artifact.json`, `manifest.json`, and `assets/`. Use `--archive /path/to/recording.pyx` on capture, export, merge or optimize to write a flat ZIP container with the `.pyx` extension. Metadata is written first; images are processed individually. The archive must be outside the input/output directories and must not already exist. Consumers choose whether to commit, use LFS, ignore, or externally persist recordings.

Argument parsing uses Apple's [Swift Argument Parser 1.8.2](https://github.com/apple/swift-argument-parser/releases/tag/1.8.2), linked only to the CLI target. Its [Swift 6.0 package manifest](https://github.com/apple/swift-argument-parser/blob/1.8.2/Package.swift) is compatible with this package's Swift 6.2 tools requirement. Library products do not link ArgumentParser.

## Optimize images before sharing

Resize while publishing a recording, or make a smaller copy of an existing recording folder or archive. ffmpeg is only required when `--image-width` is used. It is resolved from PATH; `--ffmpeg /path/to/ffmpeg` selects an explicit installation.

```sh
swift run pyxis export --xcresult .generated/run.xcresult \
  --output .generated/shared --image-width 320 \
  --archive .generated/shared.pyx

swift package --allow-writing-to-package-directory pyxis optimize .generated/map \
  --output .generated/map-320 --image-width 320 \
  --archive .generated/map-320.pyx
```

`optimize` accepts a recording folder, manifest JSON, `.pyx`, or ZIP, and defaults to 320 pixels when no width is given. Archives are validated and extracted into temporary storage that is removed after the operation. The same image/archive options work with `capture`, `export` and `merge`; those commands retain original dimensions unless a width is explicitly requested. `--image-width` must be a positive integer, preserves proportions and never enlarges smaller images. PNG/JPEG formats are retained unless `--jpeg-quality` requests conversion; reduced dimensions lose detail, and JPEG resizing re-encodes pixels.

Every state, profile, observation, capture and transition is preserved. Image dimensions, hashes and content-addressed paths are updated. Identical resulting images share storage. The publisher stages each unique image on disk immediately instead of retaining all images in memory. Original files are never changed; a failed resize or publication keeps the previous output bundle intact. An archive failure leaves the complete output directory available. Existing ZIP outputs are never replaced.

Plugin execution uses SwiftPM's normal sandbox. Give it permission for the desired output directory; if a locally installed ffmpeg cannot run under that sandbox, use the standalone `swift run pyxis` command with the same arguments.

## JPEG output

Pass `--jpeg-quality 0.5` to `capture`, `export`, `merge` or `optimize` to convert published images to JPEG. Quality is a finite number in `0...1`, passed to Apple's ImageIO lossy-compression option. Transparent images are composited over white. Dimensions stay unchanged unless `--image-width` also requests resizing. The publisher updates media types, hashes and paths and preserves all recording records.

```sh
swift run pyxis export --xcresult .generated/run.xcresult \
  --output .generated/compact --image-width 240 --jpeg-quality 0.5 \
  --archive .generated/compact.pyx
```

JPEG conversion itself uses ImageIO and does not require ffmpeg. Resizing still requires ffmpeg, including `optimize`'s default maximum width of 320. Omitting `--jpeg-quality` preserves existing behavior. Repeated JPEG conversion loses additional detail; merge already-optimized bundles without image options.

## Regular artifacts and external stores

```sh
swift run pyxis pack .generated/recording --output recording.pyx
swift run pyxis validate recording.pyx

swift run pyxis store update recording.pyx --storage /path/to/store --context main
swift run pyxis store export --storage /path/to/store --context main --output complete.pyx
```

`store update` defaults to `--policy merge`: replace matching journey/test/requested-variant scopes and retain all other recordings. `--policy update` replaces the selected context completely. Only passed recordings are accepted. Store snapshots retain the original run of each observation. `store export --snapshot <id>` exports a retained snapshot instead of the current context. Outputs must be new files; replace a consumer-owned output only after the new export succeeds.

See [recording storage](Storage.md) for the layout and [regular artifacts](../Format/artifact-1.schema.json) for the envelope. Thin artifacts are not implemented.

## Tool execution and cancellation

Tool execution uses [Swift Subprocess](https://github.com/swiftlang/swift-subprocess), linked only to the macOS CLI. Build, simulator, export, and image-processing commands run asynchronously; logs stream to their files. Interrupting the CLI cancels the active tool and its process group, then attempts temporary-simulator cleanup before exiting. Forced termination cannot run cleanup. The command plugin retains a small Foundation launcher because SwiftPM plugins cannot link library dependencies.
