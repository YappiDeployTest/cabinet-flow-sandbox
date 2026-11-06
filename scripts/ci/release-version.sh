#!/usr/bin/env bash
# Works out the version the next release of a commit gets.
#
# The version lives only in `web-vX.Y.Z` tags: the next one is the highest
# existing tag raised by the given part, and the first one is web-v2.0.0
# whatever the part. A commit the highest tag already contains has nothing
# to release, and the script fails.
#
# Prints `tag=<next tag>` and `previous=<highest tag or empty>`, one per line,
# in the format of $GITHUB_OUTPUT.
#
# Usage: scripts/ci/release-version.sh <patch|minor|major> <commit>

set -euo pipefail

part="${1:-}"
commit="${2:-}"

case "$part" in
  patch | minor | major) ;;
  *)
    echo "Usage: $0 <patch|minor|major> <commit>" >&2
    exit 64
    ;;
esac

if [[ -z "$commit" ]] || ! git rev-parse -q --verify "${commit}^{commit}" > /dev/null; then
  echo "Not a commit: '${commit}'" >&2
  exit 64
fi

previous="$(git tag -l 'web-v*' --sort=-v:refname | grep -E '^web-v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"

if [[ -z "$previous" ]]; then
  echo "tag=web-v2.0.0"
  echo "previous="
  exit 0
fi

released=0
git merge-base --is-ancestor "$commit" "$previous" || released=$?

case "$released" in
  0)
    # In Actions the prefix turns the line into the run's error annotation.
    echo "${GITHUB_ACTIONS:+::error::}Nothing to release: $(git rev-parse --short "$commit") is already released in ${previous}" >&2
    exit 1
    ;;
  1) ;;
  *) exit "$released" ;;
esac

IFS=. read -r major minor patch <<< "${previous#web-v}"

case "$part" in
  patch) patch=$((10#$patch + 1)) ;;
  minor) minor=$((10#$minor + 1)) patch=0 ;;
  major) major=$((10#$major + 1)) minor=0 patch=0 ;;
esac

echo "tag=web-v${major}.${minor}.${patch}"
echo "previous=${previous}"
