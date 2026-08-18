#!/usr/bin/env bash
#
# Builds a release and publishes it, so the one-line installer has something to
# download.
#
#     ./scripts/make-release.sh v0.1.0
#     ./scripts/make-release.sh v0.1.0 --dry-run    build the assets, publish nothing
#
# Produces two files and attaches them to a GitHub release:
#
#     hyprshell.tar.gz          the runtime tree plus a built bagent
#     hyprshell.tar.gz.sha256   what the installer checks before unpacking
#
# The names carry no version on purpose. GitHub's /releases/latest/download/
# redirect resolves by asset name, so a fixed name is what lets the installer
# fetch the newest release without first discovering which one that is.
#
# What ships is the runtime and nothing else: no tests, no harnesses, no Rust
# sources, no scripts. A user installing the shell has no use for the machinery
# that builds it, and every file that ships is a file that can go wrong.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

readonly ARCHIVE="hyprshell.tar.gz"
readonly OUT_DIR="dist"

# The runtime, exactly. Anything not named here does not reach the user.
readonly RUNTIME_ENTRIES=(
	shell.qml
	OverlayArbiter.qml
	OverlayLifecycleLoader.qml
	features
	services
	shared
	theme
	LICENSE
)

version="${1:-}"
dry_run=false
[[ "${2:-}" == "--dry-run" ]] && dry_run=true

if [[ -z "$version" ]]; then
	echo "usage: $0 <version> [--dry-run]" >&2
	echo "       version is the git tag, e.g. v0.1.0" >&2
	exit 1
fi

fail() {
	echo "-- FAILED: $*" >&2
	exit 1
}

echo "== hyprshell $version =="

for tool in cargo tar sha256sum; do
	command -v "$tool" >/dev/null 2>&1 || fail "$tool is required and not installed"
done
if [[ "$dry_run" == false ]]; then
	command -v gh >/dev/null 2>&1 || fail "gh is required to publish (or pass --dry-run)"
fi

# A release built from a dirty tree is a release nobody can reproduce from the
# tag it claims to be. A dry run publishes nothing, so it is allowed to run on
# work in progress — which is when you actually want to inspect the archive.
if [[ "$dry_run" == false && -n "$(git status --porcelain)" ]]; then
	fail "the working tree is dirty — commit or stash before releasing"
fi

echo "-- building bagent (release)"
cargo build --release --manifest-path bagent/Cargo.toml || fail "the bagent build did not finish"

readonly BUILT="bagent/target/release/bagent"
[[ -x "$BUILT" ]] || fail "$BUILT is missing after a build that reported success"

rm -rf -- "$OUT_DIR"
readonly STAGE="$OUT_DIR/hyprshell"
mkdir -p -- "$STAGE/bin" || fail "could not create $STAGE"

echo "-- staging the runtime"
for entry in "${RUNTIME_ENTRIES[@]}"; do
	[[ -e "$entry" ]] || fail "$entry is missing from the working tree"
	cp -R -- "$entry" "$STAGE/" || fail "could not stage $entry"
done

# The tests live beside the code they cover rather than in a tree of their own,
# which is the right place for them and the wrong place for a release. They are
# removed after copying instead of filtered during it, because the alternative is
# a copy that has to know the shape of every directory it walks.
find "$STAGE" -name '*.test.js' -delete
find "$STAGE" -type d -name tests -exec rm -rf -- {} + 2>/dev/null

install -Dm755 -- "$BUILT" "$STAGE/bin/bagent" || fail "could not stage bagent"
# Debug symbols are two megabytes the user downloads and never reads.
strip "$STAGE/bin/bagent" 2>/dev/null || echo "-- note: strip is unavailable, shipping unstripped"

printf '%s\n' "$version" >"$STAGE/VERSION"

echo "-- packing $ARCHIVE"
# --sort and a fixed mtime keep the same tree packing to the same bytes, so a
# rebuild of an unchanged release is verifiably the same download.
tar --sort=name \
	--mtime='UTC 2020-01-01' \
	--owner=0 --group=0 --numeric-owner \
	-czf "$OUT_DIR/$ARCHIVE" -C "$OUT_DIR" hyprshell ||
	fail "could not pack $ARCHIVE"

(cd "$OUT_DIR" && sha256sum "$ARCHIVE" >"$ARCHIVE.sha256") ||
	fail "could not write the checksum"

rm -rf -- "$STAGE"

echo "-- built:"
echo "     $OUT_DIR/$ARCHIVE ($(du -h "$OUT_DIR/$ARCHIVE" | cut -f1))"
echo "     $OUT_DIR/$ARCHIVE.sha256"

if [[ "$dry_run" == true ]]; then
	echo
	echo "Dry run — nothing was published. Inspect it with:"
	echo "    tar -tzf $OUT_DIR/$ARCHIVE | head"
	exit 0
fi

echo "-- publishing the release"
if gh release view "$version" >/dev/null 2>&1; then
	# Re-uploading onto an existing tag is how a published checksum stops
	# matching what people already downloaded, so it is refused.
	fail "release $version already exists — bump the version or delete it first"
fi

gh release create "$version" \
	--title "$version" \
	--generate-notes \
	"$OUT_DIR/$ARCHIVE" \
	"$OUT_DIR/$ARCHIVE.sha256" ||
	fail "gh could not create the release"

echo
echo "Published. The installer will pick it up as latest:"
echo
echo "    curl -fsSL https://raw.githubusercontent.com/adanft/hyprshell/main/install.sh | sh"
