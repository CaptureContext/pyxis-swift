# Recording stores

A recording store is a persistent filesystem directory chosen by the consumer. It can live outside the project, on a mounted drive, in ordinary Git, in Git LFS, or in an ignored folder. Pyxis has no required Git layout and performs no network synchronization.

## Record selectively

Add storage to the existing recording YAML:

```yaml
storage:
  path: ../recordings
  context: development
  policy: merge
```

Pass `--update-store` to `pyxis record` to opt into mutation. Without it, a configured store is untouched and the selected run produces a standalone artifact.

The path is relative to the YAML file unless absolute. Keep `output` for per-run logs, Xcode test results, coverage reports, and intermediate bundles. Those diagnostics have a separate lifetime from the durable recording store. `archive: false` disables the per-run archive. Exporting the full store is a separate `store export` command.

Only a successful invocation updates the store. With an explicit `recording_key`, the merge unit is that key plus the complete requested variant dictionary, independent of test name and producer. Without a key, the existing journey ID + test name + requested variants rule applies in a separate namespace. All executions in an incoming scope replace its previous observations, captures, and transitions together; other scopes remain. Different tests/producers cannot claim one key and profile in the same incoming update. Each variation retains its own declarations, profile and run metadata, including old labels. See [snapshot recording](SnapshotRecording.md) for mixing UI journeys and Swift Testing fixtures.

`policy: update` replaces the context with the incoming recording. It is explicit because unrecorded scopes disappear from that context. Older immutable snapshots and assets remain available in either policy. Pyxis never infers that a state was removed from a failed recording.

## Seed and export

```sh
swift run pyxis store update previous.pyx --storage ../recordings --context main
swift run pyxis store export --storage ../recordings --context main --output complete.pyx
swift run pyxis store export --storage ../recordings --snapshot SNAPSHOT_ID --output historical.pyx
```

Update accepts published folders, manifests, nested `.pyx` or `.pyxis` files. It normalizes image paths before adding them to the store. Export produces nested, self-contained test and variation archives. Archive outputs must be new files, and the original recording is never removed.

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

`store.json` identifies `pyxis.store`, version 2, and one `project_id`. Assets and snapshots are immutable. A snapshot ID is the SHA-256 of its serialized snapshot. A head contains a `snapshot_id` and advances atomically after validation. The lock serializes initialization and subsequent writes to the same filesystem store; concurrent merges read the latest head while holding it. Filesystems used by multiple processes must support advisory file locks and atomic rename.

Only `.runtime/` is operational state. Do not synchronize active locks between machines; each machine should use its own checkout or restore, then synchronize durable data through the consumer's chosen mechanism. Pyxis does not edit `.gitignore` or `.gitattributes`, commit files, or prune historical snapshots. If using LFS, consumers normally apply it to image files while keeping metadata as text.

Snapshots contain complete metadata and share asset files, so retaining snapshots does not duplicate unchanged image bytes. A version 2 snapshot contains `format: "pyxis.store.snapshot"`, `version: 2` and a `recordings` dictionary keyed by replacement slot. Every value is an original variation map, with its own run and declarations. Original timestamps and producer-supplied provenance survive selective updates. Pyxis does not claim that retained screenshots were refreshed or automatically collect Git revisions.

## CI and package plugin

CI must restore or seed the store explicitly, record its selection, and persist the desired result. A local store does not itself upload or download anything. Consumers control retention and synchronization. Regular export still includes every referenced image; thin archive transfer is deferred.

The standalone CLI can write to any authorized filesystem path. The command plugin requires write permission for external directories. Recording already uses `--disable-sandbox` for Xcode and CoreSimulator; for other commands, grant the selected directory through SwiftPM's `--allow-writing-to-directory` option.

## Swift API

```swift
let store = PyxisRecordingStore(root: URL(fileURLWithPath: "/path/to/recordings"))
let saved = try store.update(input, context: "main", policy: .merge)
try PyxisArchive().write(saved.recordings, to: URL(fileURLWithPath: "/path/to/output.pyx"))
```

`input` is a validated, published `PyxisBundleInput` with SHA-256 asset filenames. `snapshot(context:)` reads a context; `snapshot(id:)` loads a retained snapshot. Export or validation checks image integrity before use. Store updates reject failed/incomplete observations and empty recording sets.

## Interrupted writes and recovery

Each file is written and synchronized in `.runtime/staging` before an atomic rename publishes it. The context head is written last, after validating the complete snapshot. A failed write, including exhausted disk space, leaves the previous head unchanged. Retry after correcting the filesystem error; unreferenced complete assets and snapshots are safe to reuse.

After taking the writer lock and checking the project identity, the next update removes recognized temporary staging files left by an interrupted process. It rejects unexpected files and symbolic links in that directory. Recovery never prunes retained snapshots or assets, including a complete snapshot whose head update was interrupted. Initialization performs its destination checks under that same lock, so simultaneous first writers cannot mistake another writer's files for unrelated content.

These guarantees cover failed writes and process interruption on a filesystem with working locks and atomic rename. They do not replace backups or promise recovery from filesystem corruption or hardware failure.

## Explicit migration

```sh
swift run pyxis store migrate old-recordings --output recordings-v2
```

Migration copies and validates the store into a new sibling destination. It retains old snapshot IDs, heads and assets, never changes the original, and rejects symbolic links. Version 1 stores are not opened or updated implicitly. Subsequent writes use version 2 snapshots; historical version 1 snapshot bytes remain readable in the explicitly migrated store.
