# Public models

Public data models use the `Pyxis` prefix to keep their names distinct from the consuming application's types. Import `PyxisModel` when declaring them.

## States and run metadata

```swift
import Foundation
import PyxisModel

let recordingStartedAt: Date = .init(timeIntervalSince1970: 1_789_344_000)
let run: PyxisRunMetadata = .init(
	id: "example-run",
	createdAt: recordingStartedAt,
	provenance: ["fixture": "example"]
)
let state: PyxisState = .init(
	id: "home",
	screenID: "home",
	domainID: "main",
	title: "Home"
)
```

The fixed date above is illustrative. Create run metadata once per execution and share it across contributing tests and profiles. `PyxisRunMetadata` describes a run; it does not execute one. Give states stable app-owned IDs independent of their titles and screenshot bytes.

| Model | Purpose |
| --- | --- |
| `PyxisMapDocument` | Manifest containing project, run and recording records |
| `PyxisProject` | Project identity and title |
| `PyxisRunMetadata` | Run identity, creation date and producer-supplied provenance |
| `PyxisDomain` | An ordered group of screens and states |
| `PyxisState` | A named UI condition within a screen and domain |
| `PyxisProfile` | Requested variant values and initial selection order |
| `PyxisObservation` | One execution of a journey for a profile, with status and variant results |
| `PyxisCapture` | One screenshot checkpoint, with its state, observation and sequence |
| `PyxisAsset` | Image path, checksum, format and dimensions |
| `PyxisTransition` | An attempted action between states, with sequence and outcome |
| `PyxisVariantResult` | An applied, observed, unsupported or unverified variant |
| `PyxisArtifact` | Separately versioned regular archive descriptor |

`PyxisCore` provides `PyxisBootstrapReport` for transporting variant results. `PyxisXCTest` provides `PyxisRecordingConfiguration` for recorder setup. Processing types such as `PyxisBundleInput`, `PyxisRecordingStore` and `PyxisStoredRecording` belong to `PyxisProcessing`; see [processing](Processing.md) and [storage](Storage.md).

## Encoding and validation

Swift properties use camelCase. Declared JSON keys and Pyxis-owned tokens use lower snake case; app-owned IDs, titles, paths and dictionary values retain their exact spelling. `PyxisRunMetadata.createdAt` and optional `PyxisObservation.startedAt` are Foundation `Date` values encoded as ISO 8601 strings by the models. No JSON coder date strategy is needed.

Constructors do not validate a complete recording graph. Use `PyxisValidation.validate(_:)` or `PyxisJSON.decode(_:)` to check the manifest, and processing APIs to verify image files. See the [format contract](../Format/README.md) for references, uniqueness, timestamps and variant vocabulary.

## Default profile

`PyxisProfile.order` is a nonnegative integer, defaulting to zero. The viewer initially selects the profile with the lowest order and preserves document order for ties. Set it from `PYXIS_PROFILE_ORDER` when recording through YAML so the first configured combination remains the default after merging. The wire field `order` is optional; omission means zero.

## Retained runs

After selective store updates, the document's `run` describes the latest update. Each observation's optional `runID` selects its original run from the document's run metadata; omission means the top-level run. Earlier runs are retained in `recordingRuns`. Use the observation's resolved run when displaying its date and provenance, so retained screenshots are not presented as newly recorded.

## Typed variant requests

`PyxisProfile.requested` and `pyxisConfiguration.requested` use `PyxisVariants`. Compose entries with built-in factories or add your own:

```swift
let requested: PyxisVariants = [
	.colorScheme(.dark),
	.layoutDirection(.rtl),
	.accessibility(.contentSize(.xxxLarge)),
	.accessibility(.contrast(.high)),
	.device("iPhone 18 Pro"),
	.locale("en_US"),
]

extension PyxisVariantEntry {
	public enum Subscription: String {
		case trial, active
	}

	public static var subscriptionKey: String { "subscription.status" }

	public static func subscription(_ value: Subscription) -> Self {
		.init(key: subscriptionKey, value: value.rawValue)
	}
}

let trial: PyxisVariants = requested.merging([.subscription(.trial)])
```

The primary API uses entries; raw dictionary literals and `PyxisVariants(dictionary)` remain useful for configuration files and custom keys. `dictionary` exposes a value copy for integration with dictionary APIs. Later entries replace earlier values for the same key, including in `merging(_:)`. `set(_:)` updates one entry. Equality ignores order; serialization is still a JSON object. Custom keys and values are never normalized.

Built-in key constants include `colorSchemeKey`, `layoutDirectionKey`, `accessibilityContentSizeKey` and `accessibilityContrastKey`. Nested public value enums support raw-value decoding in app adapters and tests. Accessibility factories compose their relative keys under `accessibility.`; consumers can extend `PyxisVariantEntry.Accessibility` with their own entries too. A typed request still needs an adapter and a verified result. It does not imply that the operating system can apply it.

The standard theme key is `color_scheme`. Its values are `light`, `dark` and `system`. Content sizes use `x_small`, `small`, `medium`, `large`, `x_large`, `xx_large`, `xxx_large` and their documented accessibility equivalents.

`PyxisVariants` uses `OrderedDictionary` from Swift Collections. Typed entry arrays and dictionary literals retain declaration order during iteration; replacing a value keeps its position and new keys append. Dictionary inputs and decoded JSON objects use sorted keys. Equality remains independent of ordering, and encoding still produces a JSON object. In-memory order is not part of the wire format.
