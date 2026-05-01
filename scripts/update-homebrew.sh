#!/usr/bin/env bash
# ABOUTME: Update Homebrew formula with new version and SHA256.
# ABOUTME: Called by `make release` after tagging a release.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

VERSION="${1:?Usage: update-homebrew.sh VERSION}"

FORMULA_FILE="$PROJECT_DIR/homebrew/Formula/first-folio.rb"

if [[ ! -f "$FORMULA_FILE" ]]; then
    echo "Error: Formula file not found: $FORMULA_FILE" >&2
    exit 1
fi

# Compute SHA256 from the GitHub tarball
TAR_URL="https://github.com/tigger04/first-folio/archive/refs/tags/v${VERSION}.tar.gz"
echo "Downloading tarball to compute SHA256..."
SHA256=$(curl -sL "$TAR_URL" | shasum -a 256 | awk '{print $1}')

if [[ -z "$SHA256" || "$SHA256" == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]]; then
    echo "Error: failed to download tarball or empty response" >&2
    echo "  URL: $TAR_URL" >&2
    echo "  (tag v${VERSION} may not exist yet — push tags first)" >&2
    exit 1
fi

echo "Updating formula to version $VERSION..."

tmp_formula="$(mktemp)"
awk -v ver="$VERSION" -v sha="$SHA256" -v url="$TAR_URL" '
    /^  url / { print "  url \"" url "\""; next }
    /^  sha256 / { print "  sha256 \"" sha "\""; next }
    /^  version / { print "  version \"" ver "\""; next }
    { print }
' "$FORMULA_FILE" > "$tmp_formula"
mv "$tmp_formula" "$FORMULA_FILE"

echo "  version: $VERSION"
echo "  sha256:  $SHA256"
echo ""
echo "Formula updated. To publish:"
echo "  cp $FORMULA_FILE ~/code/tigoss/homebrew-tap/Formula/"
echo "  cd ~/code/tigoss/homebrew-tap && git add -A && git commit -m 'first-folio $VERSION' && git push"
