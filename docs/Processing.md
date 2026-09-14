# Format and processing reference

The package owns the [artifact](../Format/artifact-1.schema.json), [map](../Format/map-1.schema.json) and [fragment](../Format/fragment-1.schema.json) schemas and [conformance fixtures](../Format/Fixtures). JSON schemas describe structure; `PyxisValidation` also checks references, sequence uniqueness and temporal relationships.

`PyxisJSON.decode` rejects duplicate JSON keys before typed decoding, unknown versions, invalid known fields and explicit null optional fields. Unknown object fields are ignored. IDs remain author-owned opaque strings. Image hashes identify stored image bytes, not semantic states.

## Merge and publish

`MapMerger.merge` combines validated record sets in stable UTF-8 ID order and rejects identity conflicts. Its in-memory result can still contain unhashed fragment assets. Use `BundlePublisher.publish(inputs:to:)` to produce a distributable map.

Publication verifies SHA-256 when supplied, image signatures, decoded dimensions and file containment. It writes each unique image to disk without retaining the entire recording's image data, rewrites assets to content-addressed paths, fills checksums, stages a complete bundle, then atomically replaces an existing valid output. Unrelated output files and input/output directory overlap are errors.

A validation or replacement failure leaves the previous map intact. If publication succeeds but cleanup of the previous bundle fails, `PyxisPublicationCleanupError` reports the published output and leftover staging location. An archive failure leaves the published directory available; existing archive paths are never overwritten.

Image optimization preserves all recording records while updating asset dimensions, hashes and paths. See the [CLI reference](CLI.md#optimize-images-before-sharing) for ffmpeg and archive options.

## Resource usage

There are no fixed byte-size, archive-entry or image-pixel caps. Metadata and each image being processed must fit the available memory and platform decoder capabilities. The JSON parser retains its nesting-depth guard; size does not bypass structural or integrity validation. Optimize source images when smaller artifacts are useful.

See the [format contract](../Format/README.md) for stable-ID framing and cross-language validation rules. Imported manifests never execute JavaScript or fetch asset URLs.


## Regular artifacts and persistent storage

`PyxisArchive().write(_:to:)` packages a regular `.pyx`; `extract(from:to:)` validates and extracts into a new directory. ZIPFoundation handles ZIP entry compression and extraction; only referenced assets are extracted, one image at a time. `PyxisArtifact` owns the separately versioned container descriptor.

`PyxisRecordingStore` stores immutable image assets and complete metadata snapshots at an explicit filesystem URL. Named contexts advance atomically. Merge replaces selected journey/test/variant scopes while preserving unselected recordings and their original run provenance. See [Storage.md](Storage.md).
