#!/bin/sh
# Fail closed before publishing; query origin directly so stale tracking refs cannot pass.
set -eu

fail() {
    echo "Release failed: $*" >&2
    exit 1
}

branch=$(git branch --show-current)
[ "$branch" = main ] || fail "Switch to main before publishing beta or stable releases."
[ -z "$(git status --porcelain --untracked-files=all --ignore-submodules=none)" ] ||
    fail "Commit or stash all edits and untracked files before publishing."
revision=$(git rev-parse HEAD)
remote=$(git ls-remote --exit-code origin refs/heads/main) ||
    fail "Cannot verify origin/main. Check the remote and your connection."
remote_revision=$(printf '%s\n' "$remote" | cut -f1)
[ "$revision" = "$remote_revision" ] ||
    fail "main must exactly match origin/main. Pull the latest changes and merge any local commits before publishing."
