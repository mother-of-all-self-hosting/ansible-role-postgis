#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository tracking the same shape of versions this
# role tracks: a v9 whose image version starts with `9.6`, an older current
# major, and a newest major that has already seen two releases.
#
# The tags it plants deliberately include traps: releases of an older version,
# a release of a version whose name is not a prefix of the newest one, and a
# tag that starts with the newest version but does not end in a release
# counter. None of them may influence the next release number.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/vars"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	{
		printf 'postgis_container_image_v9_version: "9.6-3.2"\n'
		printf 'postgis_container_image_v17_version: "17-3.6"\n'
		printf 'postgis_container_image_v18_version: "18-3.6"\n'
	} > defaults/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > vars/main.yml
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	git tag 'v18-3.6-0'
	git tag 'v18-3.6-1'

	# Traps.
	git tag 'v17-3.6-7'
	git tag 'v15-3.3-9'
	git tag 'v18-3.6-alpine'
	git tag 'v18-3.6-rc1'
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_newest_postgis="sed -i 's|18-3.6|18-3.7|' defaults/main.yml"
bump_older_postgis="sed -i 's|17-3.6|17-3.7|' defaults/main.yml"
bump_v9_postgis="sed -i 's|9.6-3.2|9.6-3.3|' defaults/main.yml"
add_v19='printf '"'"'postgis_container_image_v19_version: "19-3.7"\n'"'"' >> defaults/main.yml'
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_vars="printf 'a var\n' >> vars/main.yml"
edit_readme="printf 'documentation\n' >> README.md"

scenario 'Bumps to the newest and to an older major, in either order'
expect 'older major (v17)'  v18-3.6-2 "$(merge "$bump_older_postgis")"
expect 'newest major (v18)' v18-3.7-0 "$(merge "$bump_newest_postgis")"

scenario 'Bumps to the newest and to an older major, the other way around'
expect 'newest major (v18)' v18-3.7-0 "$(merge "$bump_newest_postgis")"
expect 'older major (v17)'  v18-3.7-1 "$(merge "$bump_older_postgis")"

# The v9 image version starts with `9.6`, which sorts above `18` as text. Only
# sorting on the major taken from the variable name gets this right.
scenario 'A bump to v9 does not make v9 the newest version'
expect 'v9 PostGIS series' v18-3.6-2 "$(merge "$bump_v9_postgis")"

scenario 'A new Postgres major appears'
expect 'new major (v19)' v19-3.7-0 "$(merge "$add_v19")"
expect 'older major'     v19-3.7-1 "$(merge "$bump_older_postgis")"

scenario 'Commits that do not affect the role'
expect 'README' ''        "$(merge "$edit_readme")"
expect 'a task' v18-3.6-2 "$(merge "$edit_task")"
expect 'vars'   v18-3.6-3 "$(merge "$edit_vars")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v18-3.6-$release_number"
done
expect 'a task' v18-3.6-11 "$(merge "$edit_task")"

# A version that has never been released starts at 0 even though the repository
# is full of tags belonging to other versions.
scenario 'A version that has never been released'
expect 'new PostGIS series for the newest major' v18-3.7-0 "$(merge "$bump_newest_postgis")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
