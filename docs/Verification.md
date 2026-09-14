# Verification history

## Swift 6.2 and documentation audit, 2026-09-16

- The Swift 6.2 package baseline, async Subprocess execution and ordered variant storage passed 98 package tests using the installed Swift 6.4 toolchain. Cancellation checks covered child-process termination, temporary-simulator cleanup and preservation of the last published bundle.
- A real CLI recording produced a validated regular `.pyx` with two profiles, eight states and 22 captures. Coverage passed and the temporary simulator was removed. The example built for iOS Simulator, and all six macOS and five iOS interfaces were refreshed.
- Twelve Swift documentation snippets type-checked against the current iOS modules. Documented demo, pack, validate, optimize, merge, store update/export and recording-plan commands passed with temporary data. All 74 local Markdown links checked across the package, viewer and async package resolved.
- All 67 shared Swift/frontend conformance cases passed, and the frontend format copy matched the package. The production viewer opened the real artifact with the configured initial profile, verified captures, domain expansion, state inspection and an enlarged image.

## Typed variants and example workspace, 2026-09-16

- All 91 package tests passed, including typed variant composition, raw-object encoding and CLI environment validation. All 170 frontend tests and the production build passed after adopting `color_scheme`.
- The example's workspace passed an iOS Simulator build. Eight selected example tests and all 31 iOS runtime tests passed on a temporary iPhone 18 Pro / iOS 27 simulator, removed afterward.
- A CLI-driven selective YAML recording exercised both journeys with light / RTL / xxxLarge and dark / LTR / Large. Coverage passed for two profiles, eight states and 22 captures. The resulting regular `.pyx` used 240-pixel JPEG assets at quality 0.5.
- Workspace regeneration was deterministic. The example's two-target package passed the structure/README audit. The Xcode project contains no local or remote package references; the workspace supplies the example package.
- Refreshed all six macOS and five iOS public interfaces. Format files match the frontend's vendored copy, and relative documentation links resolve.

## Typed example, 2026-09-15

- The regenerated example project passed `build-for-testing` for iOS Simulator.
- Seven selected tests passed on a temporary iPhone 18 Pro / iOS 27 simulator: four typed-profile regressions, both matrix journeys using manual defaults, and the dark / xxxLarge tour. The simulator was removed afterward.
- Exported and validated the resulting XCTest attachments: eight states, three passed observations and 15 captures. Journey IDs and both profile IDs retained their previous wire values.
- This change affects example declarations only; the package public interfaces are unchanged.

## Size-cap removal, 2026-09-15

- All 84 Swift tests passed. Regressions cover archive extraction with a manifest over 64 MiB, descriptors over 1 MiB, store metadata above former caps, and requested optimization widths above 16,384 pixels.
- Regenerated six macOS and five iOS interfaces. Only the removed `BundleValidator.maximumAssetBytes` and `maximumImagePixels` constants changed the public API snapshots.
- Structural, checksum, path and decoded-dimension validation remain in place. No 10 GB end-to-end recording benchmark was performed.

## Earlier checks, 2026-09-15

- `swift test` passed 82 tests after the regular artifact, recording configuration and persistent-store recovery changes.
- Store recovery checks cover interrupted writes, first-writer concurrency, staging cleanup and preservation of the previous context on failure.
- Fresh public interfaces for all six macOS targets and five iOS libraries matched the checked-in snapshots byte-for-byte. Both standalone async-package interfaces also matched.

- The documentation audit type-checked 11 Swift snippets against the current iOS modules, including both READMEs, runtime configuration, UI test lifecycle and storage.
- Synthetic CLI checks passed for demo, pack, validation, direct `.pyx` optimization at width 240 / JPEG quality 0.5, merge, store update/export, and the example recording plan with `--list`. No new simulator recording was run for this documentation audit.
- All 70 local documentation links across the Swift package, viewer and async package resolved.

## 2026-09-14

Verified on 2026-09-14 with Xcode 27 and Apple Swift 6.4.

- `swift test` passed 48 tests using the remote `swift-async-xcuiautomation` 0.0.1 dependency.
- The standalone async package passed 6 polling tests. Its public macOS and iOS interfaces were generated.
- The README UI test examples type-checked against the iOS simulator modules and XCTest.
- Six macOS interfaces and five iOS simulator library interfaces were generated under `.agents/interfaces/`. Headers identify the expected modules, release configuration and platform triples.
- The standalone example and its UI test targets passed `xcodebuild build-for-testing` for a generic iOS simulator. This check compiled tests without launching a simulator or running new UI recordings.
- Both interface automation workflows passed actionlint 1.7.12.

Interface generation emits the compiler's expected library-evolution and scoped-import warnings. The snapshots are API references. The CLI is macOS-only and is intentionally excluded from iOS snapshots.
