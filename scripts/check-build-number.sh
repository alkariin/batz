#!/usr/bin/env bash
# Fails unless the build number of the app is greater than the build number
# of every version published before it: Android refuses to install an update
# whose version code (the build number) is not greater than the installed one.
#
# Usage: scripts/check-build-number.sh [repo-dir]
#
# The published versions are the tags `v*`; each one's build number is read
# from `batz-ui/pubspec.yaml` at that tag. The tag of the current version name
# itself (`v` + the name, suffix included) is left out, so the check also
# passes on the commit of a release. It needs the tags: in CI, check out with
# `fetch-depth: 0`.
set -euo pipefail

repo="${1:-.}"

# `NAME+BUILD`, e.g. `0.8.0-alpha+9`.
parse() {
  sed -n 's/^version: *\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\(-[0-9A-Za-z.]*\)\{0,1\}\)+\([0-9][0-9]*\) *$/\1 \3/p'
}

read -r name build < <(parse <"$repo/batz-ui/pubspec.yaml") || true
if [[ -z "${name:-}" || -z "${build:-}" ]]; then
  echo "batz-ui/pubspec.yaml: cannot read a version NAME+BUILD such as 0.8.0-alpha+9." >&2
  exit 1
fi

tags=()
while IFS= read -r tag; do
  [[ -n "$tag" && "$tag" != "v$name" ]] && tags+=("$tag")
done < <(git -C "$repo" tag -l 'v*')
if ((${#tags[@]} == 0)); then
  echo "No published version (tag v*) to compare with: fetch the tags (git fetch --tags)." >&2
  exit 1
fi

highest=-1
highest_tag=
for tag in "${tags[@]}"; do
  read -r _ tag_build < <(git -C "$repo" show "$tag:batz-ui/pubspec.yaml" | parse) || true
  if [[ -z "${tag_build:-}" ]]; then
    echo "$tag: cannot read the version of batz-ui/pubspec.yaml." >&2
    exit 1
  fi
  if ((tag_build > highest)); then
    highest=$tag_build
    highest_tag=$tag
  fi
done

if ((build <= highest)); then
  echo "Build number $build of $name is not greater than $highest, the build number of $highest_tag." >&2
  echo "Raise it in batz-ui/pubspec.yaml, or the phone refuses the update." >&2
  exit 1
fi
echo "Build number $build of $name is greater than $highest ($highest_tag), the highest of the ${#tags[@]} versions published before it."
