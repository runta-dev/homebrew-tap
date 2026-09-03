#!/bin/bash

set -euo pipefail

readonly UPSTREAM_REPOSITORY="runta-dev/runta"
readonly TAP_REPOSITORY="runta-dev/homebrew-tap"

usage() {
    cat <<'EOF'
Usage: scripts/update-runta-local.sh VERSION [--audit] [--publish]

Prepare a Homebrew Formula update from a signed Runta macOS release.

By default, the script downloads and verifies the private upstream release,
computes its SHA256, and updates Formula/runta.rb. It does not commit, push,
create a pull request, or modify a GitHub release.

With --audit, the script also runs brew audit through a temporary local tap.
This requires a native Apple Silicon Homebrew installation.

With --publish, the verified archive is also mirrored to the public
runta-dev/homebrew-tap release. Publishing is idempotent and refuses to replace
an existing asset with different contents.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

version="${1:-}"
audit=false
publish=false

case "$version" in
    -h|--help)
        usage
        exit 0
        ;;
esac

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    usage >&2
    die "VERSION must use MAJOR.MINOR.PATCH format"
fi

shift
while [ "$#" -gt 0 ]; do
    case "$1" in
        --audit)
            audit=true
            ;;
        --publish)
            publish=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown argument: $1"
            ;;
    esac
    shift
done

for command_name in codesign ditto gh git jq ruby shasum sysctl; do
    require_command "$command_name"
done

[ "$(uname -s)" = "Darwin" ] || die "this script must run on macOS"
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ] \
    || die "this script requires Apple Silicon"

repo_root="$(git rev-parse --show-toplevel)"
formula="$repo_root/Formula/runta.rb"
updater="$repo_root/scripts/update-runta-formula.rb"
tag="v${version}"
asset="runta-${version}-aarch64-apple-darwin.zip"

[ -f "$formula" ] || die "Formula not found: $formula"
[ -f "$updater" ] || die "Formula updater not found: $updater"

formula_dirty=false
if ! git -C "$repo_root" diff --quiet -- "$formula" \
    || ! git -C "$repo_root" diff --cached --quiet -- "$formula"; then
    formula_dirty=true
fi

gh auth status --hostname github.com >/dev/null

release="$(gh api "repos/${UPSTREAM_REPOSITORY}/releases/tags/${tag}")"
if ! jq -e '.draft == false and .prerelease == false' >/dev/null <<<"$release"; then
    die "${tag} is not a stable published Runta release"
fi
if ! jq -e --arg asset "$asset" '.assets | any(.name == $asset)' >/dev/null <<<"$release"; then
    die "${tag} does not contain ${asset}"
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/runta-homebrew.XXXXXX")"
local_tap_root=""
local_tap_path=""

cleanup() {
    if [ -n "$local_tap_path" ] && [ -L "$local_tap_path" ]; then
        rm "$local_tap_path"
    fi
    if [ -n "$local_tap_root" ]; then
        rmdir "$local_tap_root" 2>/dev/null || true
    fi
    rm -rf "$work_dir"
}
trap cleanup EXIT

artifact_dir="$work_dir/artifact"
extract_dir="$work_dir/extract"
mkdir -p "$artifact_dir" "$extract_dir"

gh release download "$tag" \
    --repo "$UPSTREAM_REPOSITORY" \
    --pattern "$asset" \
    --dir "$artifact_dir"

archive="$artifact_dir/$asset"
ditto -x -k "$archive" "$extract_dir"

binary_count="$(find "$extract_dir" -type f -name runta | wc -l | tr -d ' ')"
[ "$binary_count" -eq 1 ] || die "expected exactly one runta binary in $asset"

binary="$(find "$extract_dir" -type f -name runta -print -quit)"
chmod 0755 "$binary"
codesign --verify --strict --verbose=2 "$binary"

version_output="$($binary --version)"
if [[ " $version_output " != *" $version "* ]]; then
    die "binary version does not match ${version}: ${version_output}"
fi

sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
# shellcheck disable=SC2016
current_version="$(ruby -ne 'puts $1 if $_ =~ /^\s*version "([^"]+)"/' "$formula")"
if [ "$current_version" = "$version" ]; then
    # shellcheck disable=SC2016
    current_sha256="$(ruby -ne 'puts $1 if $_ =~ /^\s*sha256 "([0-9a-f]+)"/' "$formula")"
    [ "$current_sha256" = "$sha256" ] \
        || die "Formula ${version} SHA256 does not match the verified upstream asset"
    grep -Fq 'url "https://github.com/runta-dev/homebrew-tap/releases/download/v#{version}/runta-#{version}-aarch64-apple-darwin.zip"' "$formula" \
        || die "Formula ${version} does not use the public homebrew-tap release URL"
    echo "Formula is already prepared for Runta ${version}."
else
    [ "$formula_dirty" = false ] || die "Formula/runta.rb already has local changes"
    ruby "$updater" "$formula" "$version" "$sha256"
fi
ruby -c "$formula" >/dev/null

if [ "$audit" = true ]; then
    require_command brew
    if ! brew config | grep -Eq '^CPU: .*arm64'; then
        die "--audit requires a native Apple Silicon Homebrew installation"
    fi

    local_tap_root="$(brew --repository)/Library/Taps/runta-local"
    local_tap_path="$local_tap_root/homebrew-tap"
    if [ -e "$local_tap_path" ] || [ -L "$local_tap_path" ]; then
        die "temporary local tap path already exists: $local_tap_path"
    fi
    mkdir -p "$local_tap_root"
    ln -s "$repo_root" "$local_tap_path"
    HOMEBREW_NO_INSTALL_FROM_API=1 brew audit --strict runta-local/tap/runta
fi

if [ "$publish" = true ]; then
    tap_release=""
    tap_release_error="$work_dir/tap-release-error"
    if tap_release="$(gh api "repos/${TAP_REPOSITORY}/releases/tags/${tag}" 2>"$tap_release_error")"; then
        if ! jq -e '.draft == false and .prerelease == false' >/dev/null <<<"$tap_release"; then
            die "${TAP_REPOSITORY} ${tag} is not a stable published release"
        fi

        asset_count="$(jq -r --arg asset "$asset" '[.assets[] | select(.name == $asset)] | length' <<<"$tap_release")"
        [ "$asset_count" -le 1 ] || die "${TAP_REPOSITORY} ${tag} contains duplicate ${asset} assets"

        if [ "$asset_count" -eq 1 ]; then
            mirror_dir="$work_dir/mirror"
            mkdir -p "$mirror_dir"
            gh release download "$tag" \
                --repo "$TAP_REPOSITORY" \
                --pattern "$asset" \
                --dir "$mirror_dir"
            mirror_sha256="$(shasum -a 256 "$mirror_dir/$asset" | awk '{print $1}')"
            [ "$mirror_sha256" = "$sha256" ] \
                || die "existing public asset SHA256 does not match the verified upstream asset"
            echo "Public release asset already matches the verified upstream archive."
        else
            gh release upload "$tag" "$archive" --repo "$TAP_REPOSITORY"
        fi
    elif grep -q 'HTTP 404' "$tap_release_error"; then
        gh release create "$tag" "$archive" \
            --repo "$TAP_REPOSITORY" \
            --target dev \
            --title "$tag" \
            --notes "Signed and notarized Runta ${tag} macOS release."
    else
        cat "$tap_release_error" >&2
        die "failed to inspect ${TAP_REPOSITORY} ${tag}"
    fi
fi

cat <<EOF
Prepared Runta ${version} Homebrew update.
SHA256: ${sha256}
Formula: ${formula}
Public asset published: ${publish}
Homebrew audit run: ${audit}

Review the Formula diff, then commit and push it through the normal review flow.
EOF
