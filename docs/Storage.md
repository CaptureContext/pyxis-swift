# Recording stores

A recording store is a persistent filesystem directory chosen by the consumer. It can live outside the project, on a mounted drive, in ordinary Git, in Git LFS, or in an ignored folder. Pyxis has no required Git layout and performs no network synchronization.

## Record selectively

Add storage to the existing recording YAML:

```yaml
storage:
  path: ../recordings
  context: development
  policy: merge
archive: false
```

The path is relative to the YAML file unless absolute. Keep `output` for per-run logs, XCTest results, coverage reports, and intermediate bundles. Those diagnostics have a separate lifetime from the durable recording store. `archive: false` avoids repacking the full context on each recording; omit it to export automatically after success.

Only a successful invocation updates the store. The merge unit is journey ID + test name + the complete requested variant dictionary. All executions in that incoming scope replace its previous observations, captures, and transitions together. Other scopes remain. Incoming declarations take precedence; declarations needed by retained recordings remain. Conflicting profile meanings and run identities are rejected.

`policy: update` replaces the context with the incoming recording. It is explicit because unrecorded scopes disappear from that context. Older immutable snapshots and assets remain available in either policy. Pyxis never infers that a state was removed from a failed recording.

## Seed and export

```sh
swift run pyxis store update previous.pyx --storage ../recordings --context main
swift run pyxis store export --storage ../recordings --context main --output complete.pyx
swift run pyxis store export --storage ../recordings --snapshot SNAPSHOT_ID --output historical.pyx
```

Update accepts published folders, manifests, regular `.pyx` files, and existing ZIP recordings. It normalizes image paths before adding them to the store. Export produces a regular, self-contained artifact. Archive outputs must be new files, and the original recording is never removed.

Contexts are explicit ASCII-safe names of up to 128 bytes. Use names such as `main`, `feature-camera`, or `local`. Contexts do not create or follow Git branches automatically. Seed a context from a chosen artifact before making selective updates. Git merges, rebases, branch switches, and changes to uncommitted code do not select or invalidate a context.

## Layout

```text
recordings/
├── store.json
├── assets/<sha256>.jpg
├── snapshots/<snapshot_id>.json
├── heads/<context>.json
└── .runtime/
    ├── write.lock
    └── staging/<temporary_id>.tmp
```

`store.json` identifies `pyxis.store`, version 1, and one `project_id`. Assets and snapshots are immutable. A snapshot ID is the SHA-256 of its serialized manifest. A head contains a `snapshot_id` and advances atomically after validation. The lock serializes initialization and subsequent writes to the same filesystem store; concurrent merges read the latest head while holding it. Filesystems used by multiple processes must support advisory file locks and atomic rename.

Only `.runtime/` is operational state. Do not synchronize active locks between machines; each machine should use its own checkout or restore, then synchronize durable data through the consumer's chosen mechanism. Pyxis does not edit `.gitignore` or `.gitattributes`, commit files, or prune historical snapshots. If using LFS, consumers normally apply it to image files while keeping metadata as text.

Snapshots contain complete metadata and share asset files, so retaining snapshots does not duplicate unchanged image bytes. The top-level `run` describes the latest update. Observations use `run_id`; older runs are retained in `recording_runs`. Original timestamps and producer-supplied provenance survive selective updates. Pyxis does not claim that retained screenshots were refreshed or automatically collect Git revisions.

## CI and package plugin

CI must restore or seed the store explicitly, record its selection, and persist the desired result. A local store does not itself upload or download anything. Consumers control retention and synchronization. Regular export still includes every referenced image; thin archive transfer is deferred.

The standalone CLI can write to any authorized filesystem path. The command plugin requires write permission for external directories. Recording already uses `--disable-sandbox` for Xcode and CoreSimulator; for other commands, grant the selected directory through SwiftPM's `--allow-writing-to-directory` option.

## Swift API

```swift
let store = PyxisRecordingStore(root: URL(fileURLWithPath: "/path/to/recordings"))
let saved = try store.update(input, context: "main", policy: .merge)
try PyxisArchive().write(saved.bundle, to: URL(fileURLWithPath: "/path/to/output.pyx"))
```

`input` is a validated, published `PyxisBundleInput` with SHA-256 asset filenames. `snapshot(context:)` reads a context; `snapshot(id:)` loads a retained snapshot. Export or validation checks image integrity before use. Store updates reject failed/incomplete observations and empty recording sets.

## Interrupted writes and recovery

Each file is written and synchronized in `.runtime/staging` before an atomic rename publishes it. The context head is written last, after validating the complete snapshot. A failed write, including exhausted disk space, leaves the previous head unchanged. Retry after correcting the filesystem error; unreferenced complete assets and snapshots are safe to reuse.

After taking the writer lock and checking the project identity, the next update removes recognized temporary staging files left by an interrupted process. It rejects unexpected files and symbolic links in that directory. Recovery never prunes retained snapshots or assets, including a complete snapshot whose head update was interrupted. Initialization performs its destination checks under that same lock, so simultaneous first writers cannot mistake another writer's files for unrelated content.

These guarantees cover failed writes and process interruption on a filesystem with working locks and atomic rename. They do not replace backups or promise recovery from filesystem corruption or hardware failure.
