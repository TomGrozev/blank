#!/usr/bin/env bash
set -euo pipefail

# --- Argument validation ---
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/release.sh <version>"
  echo "Example: scripts/release.sh 1.2.3"
  exit 1
fi

# Validate semver format
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in MAJOR.MINOR.PATCH format (got: $VERSION)"
  exit 1
fi

# Parse components
MAJOR="${VERSION%%.*}"
REST="${VERSION#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"
INSTALL_FLOOR="${MAJOR}.${MINOR}.0"

echo "==> Releasing Blank v${VERSION} (install floor: ~> ${INSTALL_FLOOR})"
echo ""

# --- Run check suite ---
echo "==> Running checks..."
mix format --check-formatted || { echo "FAIL: mix format --check-formatted"; exit 1; }
mix compile --warnings-as-errors || { echo "FAIL: mix compile --warnings-as-errors"; exit 1; }
mix credo || { echo "FAIL: mix credo"; exit 1; }
mix doctor --summary || { echo "FAIL: mix doctor --summary"; exit 1; }
mix sobelow || { echo "FAIL: mix sobelow"; exit 1; }
mix test || { echo "FAIL: mix test"; exit 1; }
echo "==> All checks passed!"
echo ""

# --- Version bumping ---
# Detect sed variant for cross-platform support
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed_inplace() { sed -i '' "$@"; }
else
  sed_inplace() { sed -i "$@"; }
fi

echo "==> Bumping version in 5 files..."

# 1. mix.exs — @version attribute (full version)
sed_inplace "s/@version \"[^\"]*\"/@version \"${VERSION}\"/" mix.exs
echo "    mix.exs -> @version \"${VERSION}\""

# 2. lib/blank.ex — moduledoc dependency (install floor)
sed_inplace "s/{:blank, \"~> [^\"]*\"}/{:blank, \"~> ${INSTALL_FLOOR}\"}/" lib/blank.ex
echo "    lib/blank.ex -> {:blank, \"~> ${INSTALL_FLOOR}\"}"

# 3. README.md — dependency (install floor)
sed_inplace "s/{:blank, \"~> [^\"]*\"}/{:blank, \"~> ${INSTALL_FLOOR}\"}/" README.md
echo "    README.md -> {:blank, \"~> ${INSTALL_FLOOR}\"}"

# 4. guides/introduction/Getting Started.md — dependency (install floor)
sed_inplace "s/{:blank, \"~> [^\"]*\"}/{:blank, \"~> ${INSTALL_FLOOR}\"}/" "guides/introduction/Getting Started.md"
echo "    guides/introduction/Getting Started.md -> {:blank, \"~> ${INSTALL_FLOOR}\"}"

# 5. guides/introduction/Troubleshooting.md — dependency (install floor)
sed_inplace "s/{:blank, \"~> [^\"]*\"}/{:blank, \"~> ${INSTALL_FLOOR}\"}/" "guides/introduction/Troubleshooting.md"
echo "    guides/introduction/Troubleshooting.md -> {:blank, \"~> ${INSTALL_FLOOR}\"}"

echo ""
echo "==> Version bump complete!"
echo ""
echo "==> Next steps (manual):"
echo "    1. Edit CHANGELOG.md — add/update the section for v${VERSION}"
echo "    2. Review changes: git diff"
echo "    3. Commit: git commit -am \"release v${VERSION}\""
echo "    4. Publish to Hex: mix hex.publish"
echo "    5. Tag and push: git tag v${VERSION} && git push origin v${VERSION}"
