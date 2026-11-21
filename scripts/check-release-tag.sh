#!/usr/bin/env bash
# Fails unless TAG is `v` followed by the version name of the app, suffix
# included: version `0.8.0-alpha+9` is released as `v0.8.0-alpha`, never as
# `v0.8.0`. Obtainium then reads the same version in the tag and in the
# installed app. Run by the release workflow before building anything.
#
# Usage: scripts/check-release-tag.sh TAG [repo-dir]
set -euo pipefail

tag="${1:?usage: scripts/check-release-tag.sh TAG [repo-dir]}"
repo="${2:-.}"

name=$(sed -n 's/^version: *\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\(-[0-9A-Za-z.]*\)\{0,1\}\)+[0-9][0-9]* *$/\1/p' \
  "$repo/batz-ui/pubspec.yaml")
if [[ -z "$name" ]]; then
  echo "batz-ui/pubspec.yaml: cannot read a version NAME+BUILD such as 0.8.0-alpha+9." >&2
  exit 1
fi
if [[ "$tag" != "v$name" ]]; then
  echo "::error::batz-ui/pubspec.yaml says $name, so the release must be v$name, not $tag"
  exit 1
fi
echo "Tag $tag matches the app version $name."
