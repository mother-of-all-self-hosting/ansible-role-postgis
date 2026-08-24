#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# This role tracks one container image version per supported Postgres major
# (`postgis_container_image_v17_version`, `postgis_container_image_v18_version`,
# ...). Those values are compound: `18-3.6` means Postgres 18 with PostGIS 3.6.
# Only the newest tracked major defines the tag, which looks like
# `v<newest image version>-<release>`:
#
# - if defaults/main.yml points at a newest version that has never been
#   released, the release counter restarts at 0 (`v18-3.6-0`)
# - otherwise the counter is incremented (`v18-3.6-1`), but only if something
#   that actually affects the role has changed since the last release
#
# A bump to an older major (say v15) therefore does not produce a misleading
# `v15-x.y` tag - it increments the newest version's counter, and the fix still
# reaches consumers through that release. This reproduces the naming of the
# tags this repository already carries (`v15-3.3-1`, `v18-3.6-2`).
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
	'vars'
)

# The value of the highest-numbered postgis_container_image_v<N>_version.
#
# The major is taken from the variable name and sorted numerically, so that v9
# does not outrank v10 and the leading `9.6` of the v9 image version does not
# outrank the leading `18` of the v18 one.
version="$(grep -E '^postgis_container_image_v[0-9]+_version:' "$defaults_path" \
	| sed -E 's|^postgis_container_image_v([0-9]+)_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1 \2|' \
	| sort -k1,1n | tail -n1 | cut -d' ' -f2)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the newest image version from $defaults_path"
	exit 1
fi

tag_prefix="v${version}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9. The `^[0-9]+$`
# filter drops anything the glob happened to catch that is not a release
# counter, and the glob itself keeps the releases of other versions out.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
