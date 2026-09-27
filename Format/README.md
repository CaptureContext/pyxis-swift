# Pyxis recording and document formats

This is the implementation contract for the first independent Pyxis release. It is a new format, with no implicit compatibility with Myo schema 1/2. Do not reuse Myo's canonical JSON identity assumptions.

## Envelope and records

Manifest record keys use `lower_snake_case`, including acronym suffixes such as `screen_id`. Swift and TypeScript APIs retain their idiomatic camelCase property names; explicit serialization mappings define the wire format. Pyxis-defined variant key segments and multiword token values also use lower snake case, for example `accessibility.content_size` and `accessibility_xxx_large`. Dots continue to separate namespaces. Format identifiers (`pyxis.map`, `pyxis.fragment`), MIME types, IDs, titles, action descriptions, timestamps, paths, platform identifiers such as `en_US`, and consumer-owned dictionary keys and values retain their exact spelling. Serializers do not normalize arbitrary strings.

A UTF-8 JSON manifest has these required fields:

```ts
interface MapDocument {
  format: "pyxis.map"; version: 1;
  project: { id: string; title: string };
  run: { id: string; created_at: string; provenance: Record<string,string> };
  recording_runs?: { id: string; created_at: string; provenance: Record<string,string> }[];
  domains: Domain[]; states: State[]; profiles: Profile[];
  observations: Observation[]; captures: Capture[]; transitions: Transition[];
}
interface Domain { id: string; title: string; order: number }
interface State {
  id: string; screen_id: string; domain_id: string;
  title: string; label: string; order: number; metadata: Record<string,string>;
}
interface Profile { id: string; title: string; requested: Record<string,string>; order?: number }
interface VariantResult {
  status: "applied" | "observed" | "unsupported" | "unverified";
  value?: string; reason?: string;
}
interface Observation {
  id: string; journey_id: string; title: string; test_name: string; profile_id: string;
  status: "passed" | "failed" | "incomplete";
  variants: Record<string,VariantResult>;
  started_at?: string; failure?: string; run_id?: string;
  recording_key?: string;
  producer?: { framework: string; capture_method: string };
}
interface Capture {
  id: string; state_id: string; observation_id: string; sequence: number;
  asset: { path: string; sha256?: string; media_type: "image/png" | "image/jpeg"; width: number; height: number };
}
interface Transition {
  id: string; observation_id: string; from_state_id: string; to_state_id: string;
  action: string; kind: string; sequence: number;
  status: "succeeded" | "failed"; failure?: string;
}
```

A fragment has the identical record layout with `format: "pyxis.fragment"`, `version: 1` and exactly one observation. It carries the referenced declarations and capture files. These contracts have independent discriminators and will evolve separately. Raw assets may omit sha256; every published asset must have lowercase 64-character SHA-256. Published and raw observations preserve all executions, including repeated checkpoints and failures. Timestamp strings use Gregorian years 0001–9999, valid calendar dates, hours 00–23, minutes/seconds 00–59 and an explicit Z or ±HH:MM timezone (offset hours 00–23/minutes 00–59); leap seconds and 24:00 are not accepted. Optional fractional seconds are allowed; sequence/order/dimensions are integers, sequence/order >= 0, dimensions > 0. All integers are at most 9007199254740991 (JavaScript safe integer maximum). IDs and required descriptive strings are nonempty (label, failure, reason, variant values and all dictionary values can be empty; dictionary keys must be nonempty). IDs are opaque, case-sensitive strings, unique within their record category. State IDs are author-owned and project-wide, e.g. home.empty. No title or image hash defines semantic identity.

Duplicate JSON object keys are rejected, including escaped spellings and Unicode canonically-equivalent spellings of the same key. This collision check prevents Swift dictionaries from losing an entry; it does not normalize IDs or string values. Unknown object fields are ignored for forward additions; unknown version, enum values and malformed known fields are rejected. Readers must validate references and uniqueness before rendering or processing. Each requested variant must have a result entry on its observation; omitted/unhandled requests become unverified with a reason at recording time, not silently applied. Applied/observed require value; unsupported/unverified require reason. Results may also record environmental dimensions that were not requested.

Transitions require their source to have been captured earlier in that observation. A succeeded transition requires a later capture of its destination. A failed transition may have an uncaptured destination, but that state must still be declared. Sequences are unique across captures and transitions within an observation; gaps are allowed. Passing observations may not contain failed transitions. Fragments merged into a map must agree on project, run, and duplicate declarations; conflicting identities are errors. Observations, captures, and transitions may be deduplicated only when the full records are equal. Stable sorting must make merging independent of fragment input order.

## Variant vocabulary

Values use strings for a small interoperable format and adapters can interpret them. No implicit Cartesian expansion. Initial documented keys:

| Key | Example values / ownership |
| --- | --- |
| color_scheme | light, dark, system; window traits |
| device | consumer label such as iPhone 18 Pro, or a model identifier; orchestration/verified by app adapter |
| os | runtime version; observed |
| orientation | portrait, landscape_left, landscape_right; test driver |
| locale | en_US, pl_PL; launch/app adapter |
| language | en, pl; launch/app adapter |
| accessibility.content_size | large, accessibility_xxx_large; UIKit trait |
| accessibility.contrast | normal, high; UIKit trait |
| accessibility.reduce_motion | true, false; observed or app adapter |
| accessibility.reduce_transparency | true, false; observed or app adapter |
| accessibility.bold_text | true, false; observed or app adapter |
| accessibility.color_filters | off, grayscale, project-specific; unsupported until explicitly verified |
| subscription.status | none, trial, active, expired; app adapter |
| subscription.trial_eligibility | eligible, ineligible; app adapter |
| auth, onboarding, fixture, connectivity | app-owned values/adapters |
| clock, time_zone, calendar | fixed ISO date / identifiers; app adapters |
| permission.camera, feature.example | app adapters |
| custom.* | consumer extension keys |

Bootstrap parses an explicit launch payload only when opted in by the app. It supplies per-key adapters and reports results. It must not change production launch behavior automatically. UIKit window traits can set appearance/content size/contrast; they are not global simulator settings. Never claim color-filter pixels are captured without proof. The recorder accepts an explicit report from the consumer; bootstrap and test process do not magically share memory. Provide a report transport recipe (e.g. an app-owned accessibility diagnostic element) and default to unverified where reports are unavailable.

## Assets and transport

A published bundle contains `artifact.json`, `manifest.json`, and `assets/...` files. A regular `.pyx` is a ZIP of that directory with metadata at its root. The browser opens `.pyx` recordings as new pages and imports portable `.pyxis` documents from selected files, drops, or an explicit archive URL. Folder and raw ZIP inputs remain available to publication tools. Raw recordings may omit `artifact.json`; a regular `.pyx` must include it. The artifact descriptor and manifest have independent version numbers. Paths use ASCII-safe relative POSIX segments (`[A-Za-z0-9._-]+`), reject empty, dot, dot-dot, backslash, absolute paths, schemes, query, fragments and percent encodings. Never fetch a manifest asset URL from the network. Resolve files beneath bundle root, including symlink containment on disk. Duplicate ZIP entries and inconsistent asset descriptors are errors. Do not render SVG/HTML supplied as images. Verify asset SHA-256 and file type before displaying; errors must preserve the previous valid map.

## Identity and processing

Core merge and publication run in the local Swift CLI. The browser validates the same contract, projects a graph, and computes optional image comparisons on demand; it does not duplicate XCTest merging. Export retains repeated captures even with identical pixels.

Public stable-ID helper: SHA-256 of concatenated UTF-8 parts framed as ASCII decimal byte length + ':' + raw bytes, with no separator after bytes. Include a domain tag as the first part. The deterministic observation helper uses `observation, projectID, runID, journey_id, test_name, profile_id, attempt`; for capture `capture, observation_id, state_id, occurrence`; for transition `transition, observation_id, sequence`. Prefix outputs `o_`, `c_`, `t_`. Numeric components use plain base-10. No Unicode normalization. This is a Pyxis identity contract, not Myo compatibility. Run IDs are producer-owned; reproducibility means traceable conditions, not identical runs across different environments. The recording adapters use the same framing with `execution, projectID, runID, recording_key ?? journey_id, test_name, profile_id, execution_id` for observations. Each session generates a UUID execution ID (XCTest also includes its configured attempt), so retries, parameter cases and multiple blocks cannot overwrite each other. These opaque observation IDs are independent of replacement keys.

Publication validates all inputs/assets first, writes a sibling staging directory, then replaces the target with rollback on failure. Do not delete the last valid map before validation. Full run provenance can include toolchain, SDK, simulator/runtime, source revision, fixture version and capture profile source; do not collect secrets/environment dumps.

Browser consistency inspection compares selected captures of the same state after profile/result differences are visible. Decoded RGBA differences and dimension mismatch are inspection data, not baseline assertions. Use per-channel tolerance 8 by default; compare every selected distinct pair when grouping, because tolerance is not transitive. Byte hashes are integrity checks, not visual equality.

## Versioning and conformance

Package Format contains JSON Schema and tiny synthetic valid/invalid fixtures. Frontend vendors exact copies so both repositories build independently. Tests cover unknown versions, missing references, conflicts, failed transitions, repeated captures, missing/unsupported variants, corrupt hashes and unsafe paths. A Swift-produced example bundle must import into the production frontend. This repository ignores generated capture outputs and tracks tiny synthetic fixtures. Consumers choose their own storage and Git policy.

Profile `order` is an optional nonnegative integer, defaulting to 0. Viewers select the lowest ordered profile initially; ties preserve document order. Recorders can preserve the first configuration as the default even when publication sorts profiles by ID.


## Recording and visualization envelopes

Container versions are independent of the evidence manifest. New recording writers use `pyxis.artifact` version 2; map and fragment records remain version 1. Legacy `artifact-1.schema.json` and its fixtures are frozen for explicit migration only.

A regular leaf `.pyx` is a ZIP with `artifact.json`, `manifest.json`, and referenced images. Its descriptor is `{ "format": "pyxis.artifact", "version": 2, "type": "regular", "id": "immutable-recording-id" }`. A composition has `type: "composition"` and a nonempty `recordings` array instead of a manifest. Each reference contains `id`, `path` under `assets/` ending in `.pyx`, and the lowercase SHA-256 of the complete child ZIP. These are physical archives, not virtual directories. Extracting any child produces an independently usable recording.

```text
recording.pyx                         # ZIP, immutable recording ID
├── artifact.json                    # composition, references test archives
└── assets/recording-0.pyx            # ZIP, test contribution
    ├── artifact.json                # composition, references variations
    └── assets/recording-0.pyx        # ZIP, complete test/configuration variation
        ├── artifact.json            # regular, immutable variation ID
        ├── manifest.json            # map v1, original run/capture identities
        └── assets/<sha256>.png       # all images needed by this variation
```

Compositions may contain other compositions. Reference IDs and child descriptors must agree. A repeated immutable ID must refer to identical archive bytes; conflicting contents, missing children, bad hashes, duplicate paths, unsafe paths and symlinks are errors. IDs are opaque; filenames do not establish semantic identity. The Swift writer uses deterministic ZIP entry timestamps and content-derived IDs. Other writers may use fresh UUIDs. New subsets/compositions need new IDs; copying archive bytes preserves identity. Do not rewrite an existing archive under its old ID.

`.pyxis` is a ZIP with `document.json` and all `.pyx` recordings referenced by its pages:

```text
app.pyxis
├── document.json                    # pyxis.document v1; persistent ID/title/pages
└── assets/recording-0.pyx            # original embedded recording, including children
```

The document has `format`, `version`, `id`, `title`, `recordings`, and `pages`. Each page has a persistent `id`, `title`, and unique `recording_ids` resolved against the document's embedded recordings. Multiple pages may share a recording. An ordinary page can combine recordings from different runs and configurations. Empty pages/documents are valid. A page is not an app version. Temporary comparisons, selection, grouping, camera position and comparison controls are viewer state and are not serialized in 0.1.0. Recording archives contain no layout.

Readers validate relative paths, duplicate keys/entries, references, ZIP CRCs, asset checksums and decoded image dimensions. Image verification may be lazy before display; explicit migration verifies every image. There are no fixed byte-size, entry-count or image-pixel caps. Available resources and platform capabilities determine what can be processed. Imported assets never resolve over the network or execute code.

## Canvas identity and comparison

`(project.id, state.id)` identifies a logical state. Composition retains source state labels, captures, profiles, native test origins, run IDs and provenance; it does not rewrite old evidence using newer labels. Repeated references to the same `(project.id, run.id, capture.id)` do not invent another execution. Distinct capture IDs survive even when their pixels match.

A transition may supply a nonempty stable `key`, independent of its execution `id`. Diff matches keyed connections by application/key and unkeyed connections only when endpoints are unambiguous. Parallel edges can be paired explicitly in the viewer. Diff uses selected presentation graphs and captures, ignoring domain grouping and layout. Added/removed describes those chosen inputs only. Optional app version belongs in run provenance (`app_version`); recording date is a display fallback, never an identity.

## Migration and store boundaries

Browser drops, file imports and archive URLs prompt before converting artifact v1 to a new in-memory recording. Cancellation and validation failure preserve existing pages and the original archive. CLI users invoke `pyxis migrate old.pyx --output new.pyx`. Existing browser-saved maps migrate explicitly into a separate document database; originals remain available. Store v1 requires `pyxis store migrate old-store --output new-store`; old revisions retain their bytes/IDs in the new store and the original directory is preserved.

A store update consumes complete passed test/configuration contributions. It has no screen/state trimming option. A review selection or arbitrary manually trimmed manifest is not evidence of a whole variation and must not be submitted as its replacement. Use a separately authored recording key for independently replaceable fixture subsets. Store v2 keeps variation manifests independently and shares content-addressed assets; export restores physical nested archives. An entire multi-input update advances one head only after every input validates.

## Retained recording provenance

`recording_runs` is an optional array of run metadata using the same shape as `run`; it defaults to empty. `observation.run_id` optionally selects the original run. If omitted, that observation belongs to the top-level `run`. Run IDs must be unique across both locations and every explicit reference must resolve. Explicit null is invalid. The top-level run identifies the latest update of a combined recording; retained observations keep their original run identity, timestamp and provenance. Storage composition populates these fields without changing capture/observation identities. A reader must use an observation's resolved recording run when displaying its provenance.

## Recording ownership and producer provenance

The optional `recording_key` is a nonempty, consumer-owned contribution ID. When present, store merge replacement uses `(recording_key, requested profile values)` within one project/context. Test names, journey names, profile IDs and producer metadata do not participate in that scope. Different keys coexist, even when they capture the same state. Reuse a key deliberately to change its producer. Parameterized fixtures should include their stable case identity in the key when they are independently replaceable.

An observation without a key keeps the existing `(journey_id, test_name, requested values)` replacement rule. That namespace is disjoint from explicit keys. These optional fields are additive format-1 fields; absence remains valid and explicit null is invalid. Use updated producers and CLI together when relying on key-based replacement.

`producer` contains nonempty `framework` and `capture_method` strings. Current adapters emit `xctest` with `application` or `screen`, and `swift_testing` with `snapshot_testing`. These are provenance, never UI variants. All executions receive separate observation IDs; state IDs remain project-wide semantic identities. A store merge preserves each retained variation's state/domain declarations even when newer variations use different labels. One incoming update cannot assign the same key and requested conditions to different test/journey/producer owners; repeated executions of one owner remain distinct observations.

Swift Testing fragments remain incomplete until xcresult export finds their completion attachment and verifies the native test outcome. A failed native test stays failed, including nonthrowing expectation failures. Missing, skipped, unknown or ambiguous successful outcomes remain incomplete. A test with a failed retry is conservatively rejected as a whole; the exporter does not guess which parameter/retry owns an aggregate pass. Final passed observations alone may update a recording store.
