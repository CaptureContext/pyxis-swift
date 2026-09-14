#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${RELEASE_SHA:?RELEASE_SHA is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
asset="${1:?Pass the validated example archive}"
[[ -s "$asset" ]] || { echo "The release archive is missing or empty." >&2; exit 1; }
[[ "$RELEASE_TAG" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || exit 1
[[ "$RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]] || exit 1

# A retry may find the tag created by the previous publish attempt. Never move it.
git fetch --tags origin
if git show-ref --verify --quiet "refs/tags/$RELEASE_TAG"; then
  [[ "$(git rev-parse "refs/tags/$RELEASE_TAG^{commit}")" == "$RELEASE_SHA" ]] || {
    echo "Release tag already points at a different commit." >&2
    exit 1
  }
else
  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  git tag --annotate "$RELEASE_TAG" "$RELEASE_SHA" --message "Release $RELEASE_TAG"
  git push origin "refs/tags/$RELEASE_TAG"
fi

if draft="$(gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --json isDraft --jq .isDraft)"; then
  [[ "$draft" == true ]] || {
    echo "Release $RELEASE_TAG is already published; refusing to replace its attachment." >&2
    exit 1
  }
else
  gh release create "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
    --verify-tag --draft --title "$RELEASE_TAG" --generate-notes \
    --prerelease=false
fi

# Assets may be replaced only while this release is a draft. Publish after upload succeeds.
gh release upload "$RELEASE_TAG" "$asset" --repo "$GITHUB_REPOSITORY" --clobber
gh release edit "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" \
  --draft=false --prerelease=false --latest
