#!/usr/bin/env bash

# Shared helpers for the asdf/mise `nub` plugin: version listing, release-asset
# target detection, checksum verification, and download/install of a GitHub
# release tarball. Sourced by every script under bin/.

set -euo pipefail

GH_REPO="https://github.com/nubjs/nub"
TOOL_NAME="nub"

fail() {
  echo -e "asdf-$TOOL_NAME: $*" >&2
  exit 1
}

# GITHUB_API_TOKEN / GITHUB_TOKEN lift the 60-req/hr unauthenticated rate limit
# that shared-IP CI runners routinely hit. Real users pass neither and use the
# anonymous path unchanged.
gh_curl() {
  local -a auth=()
  local token="${GITHUB_API_TOKEN:-${GITHUB_TOKEN:-}}"
  [ -n "$token" ] && auth=(-H "Authorization: token $token")
  curl -fsSL "${auth[@]}" "$@"
}

# All release versions, one per line, `v`-stripped. `git ls-remote --tags`
# returns every tag in one request — no API pagination and no rate limit — which
# is strictly more robust than walking /releases pages. nub tags each release
# `v<semver>` and publishes no bare tags, so tags == releases.
list_all_versions() {
  git ls-remote --tags --refs "$GH_REPO" 2>/dev/null |
    grep -oE 'refs/tags/v[0-9].*' | cut -d/ -f3- | sed 's/^v//'
}

# The asdf plugin-template semver sort: oldest -> newest, prereleases before
# their release. xargs-joined by the callers into a single space-separated line.
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# The latest non-prerelease. /releases/latest excludes drafts and prereleases at
# the source, so it is correct even once nub starts cutting prereleases (a plain
# tag sort could not distinguish them).
latest_stable_version() {
  gh_curl "https://api.github.com/repos/nubjs/nub/releases/latest" |
    grep -oE '"tag_name":[[:space:]]*"[^"]+"' | head -n1 |
    sed -E 's/.*"v?([^"]+)".*/\1/'
}

# Release-asset target for the current platform, mirroring nub's own install.sh:
# darwin/linux x arm64/x64, `-musl` on non-glibc Linux, and the Rosetta case
# where an x64 shell on Apple Silicon should still take the native arm64 build.
release_target() {
  local os arch target
  os=$(uname -s)
  arch=$(uname -m)
  case "$os $arch" in
    'Darwin arm64') target=darwin-arm64 ;;
    'Darwin x86_64') target=darwin-x64 ;;
    'Linux aarch64' | 'Linux arm64') target=linux-arm64 ;;
    'Linux x86_64') target=linux-x64 ;;
    *) fail "unsupported platform: $os $arch (nub ships darwin/linux on arm64/x64 only)" ;;
  esac

  if [ "$target" = darwin-x64 ] &&
    [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
    target=darwin-arm64
  fi

  if [[ "$target" == linux-* ]]; then
    if [ -f /etc/alpine-release ] || ldd --version 2>&1 | grep -qi musl; then
      target="${target}-musl"
    fi
  fi

  echo "$target"
}

release_url() {
  echo "$GH_REPO/releases/download/v${1}/nub-$(release_target).tar.gz"
}

# Verify $1 against its published `.sha256` sidecar. Refuses to proceed when no
# checksum tool is present — an unverifiable download is treated as a failure,
# never silently trusted.
verify_checksum() {
  local file="$1" url="$2" expected actual
  local sha_tool
  if command -v sha256sum >/dev/null 2>&1; then
    sha_tool="sha256sum"
    actual=$(sha256sum "$file" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    sha_tool="shasum -a 256"
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  else
    fail "no sha256 tool (sha256sum/shasum) found; refusing to install unverified download"
  fi

  expected=$(gh_curl "${url}.sha256" | awk '{print $1}') ||
    fail "could not fetch checksum: ${url}.sha256"
  [ -n "$expected" ] || fail "empty checksum from ${url}.sha256"

  [ "$actual" = "$expected" ] ||
    fail "checksum mismatch for nub $ASDF_INSTALL_VERSION
  expected: $expected
  actual:   $actual  (via $sha_tool)"
}

# Download the tarball for $version, verify its checksum, and extract it into
# $target_dir so that $target_dir/bin/nub exists.
download_release() {
  local version="$1" target_dir="$2" url tarball
  url=$(release_url "$version")
  tarball="${target_dir}/nub.tar.gz"

  echo "* Downloading $TOOL_NAME $version ($(release_target))..." >&2
  gh_curl -o "$tarball" "$url" || fail "could not download $url"

  verify_checksum "$tarball" "$url"

  tar -xzf "$tarball" -C "$target_dir" || fail "could not extract $tarball"
  rm -f "$tarball"
  [ -f "$target_dir/bin/nub" ] || fail "archive did not contain bin/nub"
}
