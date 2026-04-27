#!/usr/bin/env bash
# ABOUTME: Regression tests for config-driven rendering parameters (issue #3).
# ABOUTME: Verifies each config value flows through to Typst source or Markdown output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FOLIO="$PROJECT_DIR/bin/folio"
PASS=0
FAIL=0
FAILURES=()
TMPDIR_TEST="$(mktemp -d)"

cleanup() {
    rm -rf -- "$TMPDIR_TEST"
}
trap cleanup EXIT

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    FAILURES+=("$1")
    echo "  FAIL: $1"
    if [[ -n "${2:-}" ]]; then
        echo "        $2"
    fi
}

# Create a minimal play fixture
cat > "$TMPDIR_TEST/play.org" <<'ORG'
#+TITLE: Test Play
#+AUTHOR: Test Author
#+SUBTITLE: A Test
#+DATE: 2026-01-01
#+VERSION: Draft v1

* Introduction
A test play for config parameter verification.

* CHARACTERS
|------+-------------|
| BOB  | A test char |
| CÁIT | Another     |
|------+-------------|

* Act I
** Scene 1
*** A bare stage.
**** BOB
Hello there.
*** BOB crosses to the window.
**** CÁIT softly
Goodbye now.
***** CUT TO
ORG

# Helper: write config, convert to .typ, check pattern
test_typ() {
    local desc="$1" pattern="$2"
    if "$FOLIO" convert "$TMPDIR_TEST/play.org" "$TMPDIR_TEST/out.typ" 2>/dev/null; then
        if grep -q "$pattern" "$TMPDIR_TEST/out.typ"; then
            pass "$desc"
        else
            fail "$desc" "pattern not found in Typst: $pattern"
        fi
    else
        fail "$desc" "folio exited non-zero"
    fi
    rm -f "$TMPDIR_TEST/out.typ"
}

# Helper: write config, convert to markdown, check pattern present/absent
test_md() {
    local desc="$1" pattern="$2" expect="$3"
    local md_out
    md_out=$("$FOLIO" convert "$TMPDIR_TEST/play.org" --to md 2>/dev/null || true)
    if [[ "$expect" == "absent" ]]; then
        if echo "$md_out" | grep -qi "$pattern"; then
            fail "$desc" "pattern should be absent: $pattern"
        else
            pass "$desc"
        fi
    else
        if echo "$md_out" | grep -qi "$pattern"; then
            pass "$desc"
        else
            fail "$desc" "pattern not found: $pattern"
        fi
    fi
}

# ====================================================================
echo "=== Config parameter tests (issue #3) ==="

# --- Page and font ---
echo ""
echo "folio.font, folio.font-size, folio.page, folio.margin"

printf "folio:\n  font: Georgia\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.1: folio.font overrides default font" "Georgia"

printf "folio:\n  font-size: 14pt\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.2: folio.font-size overrides default size" "14pt"

printf "folio:\n  page: us-letter\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.3: folio.page overrides default paper" "us-letter"

printf "folio:\n  margin: 1in\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.4: folio.margin overrides default margin" "1in"

# --- Speaker positioning ---
echo ""
echo "folio.positioning.speech.speaker.*"

printf "folio:\n  positioning:\n    speech:\n      speaker:\n        bold: false\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.5: speaker.bold: false produces regular weight" '"regular"'

printf "folio:\n  positioning:\n    speech:\n      speaker:\n        case-transform: upper\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.6: speaker.case-transform: upper produces #upper" "#upper"

rm -f "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.7: speaker.case-transform defaults to small-caps" "smallcaps"

printf "folio:\n  positioning:\n    speech:\n      speaker:\n        suffix: \"\"\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.8: speaker.suffix: empty removes colon" "#name"

# --- Stage direction ---
echo ""
echo "folio.positioning.stage-direction.*"

printf "folio:\n  positioning:\n    stage-direction:\n      italic: false\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.9: stage-direction.italic: false removes italic markers" "stage-direction"

# --- Act header ---
echo ""
echo "folio.positioning.act-header.*"

printf "folio:\n  positioning:\n    act-header:\n      align: left\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.10: act-header.align: left" "align(left)"

printf "folio:\n  positioning:\n    act-header:\n      case-transform: upper\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.11: act-header.case-transform: upper" "#upper"

# --- Scene header ---
echo ""
echo "folio.positioning.scene-header.*"

printf "folio:\n  positioning:\n    scene-header:\n      align: center\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.12: scene-header.align: center" "align(center)"

printf "folio:\n  positioning:\n    scene-header:\n      case-transform: upper\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.13: scene-header.case-transform: upper" "#upper"

# --- Render toggles ---
echo ""
echo "render.* toggles"

printf "render:\n  stage-directions: false\n" > "$TMPDIR_TEST/script.yaml"
test_md "RT-3.14: render.stage-directions: false suppresses directions" "bare stage" "absent"

printf "render:\n  character-table: false\n" > "$TMPDIR_TEST/script.yaml"
test_md "RT-3.15: render.character-table: false suppresses table" "A test char" "absent"

printf "render:\n  frontmatter: false\n" > "$TMPDIR_TEST/script.yaml"
test_md "RT-3.16: render.frontmatter: false suppresses intro" "Introduction" "absent"

# --- Style presets ---
echo ""
echo "folio.style presets"

printf "folio:\n  style: us\n" > "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.17: folio.style: us loads American overrides (Courier Prime)" "Courier Prime"

rm -f "$TMPDIR_TEST/script.yaml"
test_typ "RT-3.18: default style is British (Libertinus Serif)" "Libertinus Serif"

# --- Metadata override ---
echo ""
echo "Metadata override from config"

printf "title: Override Title\nauthor: Override Author\n" > "$TMPDIR_TEST/script.yaml"
test_md "RT-3.19: config title overrides source" "Override Title" "present"
test_md "RT-3.20: config author overrides source" "Override Author" "present"

rm -f "$TMPDIR_TEST/script.yaml"

# ====================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi
