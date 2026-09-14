# Releasing

Run the **Release** workflow in GitHub Actions and choose `major`, `minor`, or `patch`. The workflow file is `.github/workflows/release.yml` and uses only `workflow_dispatch`.

The next version comes from the highest numeric `major.minor.patch` tag in the repository. Tags with a `v` prefix, prerelease suffix, or leading zero are ignored. If there are no matching tags, the starting version is `0.0.0`, so the first patch release is `0.0.1`.

| Bump | Starting at `1.2.3` |
| --- | --- |
| major | `2.0.0` |
| minor | `1.3.0` |
| patch | `1.2.4` |

The workflow checks out the commit selected at dispatch, runs the package tests, builds the CLI, records the example, and validates its `.pyx` archive. Only then does it create an annotated tag at that commit and a GitHub release with generated release notes. Release runs share one concurrency group.

## Example attachment

Every release includes `pyxis-example.pyx`. The recording configuration derives from `Example/pyxis.yaml`, retaining its variants, coverage requirements, and image settings. CI uses one iPhone 17 Pro simulator on `macos-26`. It disables the local recording store so each attachment contains a fresh snapshot from that release.

The workflow installs `ffmpeg` and `xcodegen` when needed. It expects `capturecontext/swift-async-xcuiautomation` to be publicly accessible. No custom secrets or variables are required. Publication uses the automatic GitHub Actions token with `contents: write` permission.

For a specific release, the attachment URL is:

```text
https://github.com/capturecontext/pyxis-swift/releases/download/<version>/pyxis-example.pyx
```

The latest release uses the same asset name:

```text
https://github.com/capturecontext/pyxis-swift/releases/latest/download/pyxis-example.pyx
```

These URLs inherit repository access restrictions. Browser imports also require the serving host to allow cross-origin requests. Publishing the attachment does not configure frontend access or CORS.

## Failed runs

Recording failures upload diagnostics as an Actions artifact. A failed recording or archive validation does not create a tag.

Publication creates a draft release, uploads the archive, then publishes the release. If upload or publication fails, rerun the failed publish job while its Actions artifact is available, retained for seven days. The job can reuse a tag at the same commit and replace an attachment on a draft release. It refuses to move an existing tag or replace an attachment on an already published release.

Rerunning the entire workflow calculates a new version from the tags present at that time. Use **Re-run failed jobs** to retry publication of the original version.

## Local checks

The release helper tests use temporary local Git repositories and a fake GitHub CLI. They do not publish anything.

```sh
python3 -m unittest discover -s scripts/tests -p 'test_release*.py'
python3 scripts/release_version.py --bump patch
ruby scripts/release_recording_config.rb > /tmp/pyxis-release-recording.json
swift run pyxis record --config /tmp/pyxis-release-recording.json --list
```
