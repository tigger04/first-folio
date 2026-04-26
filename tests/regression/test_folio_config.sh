#!/usr/bin/env bash
# ABOUTME: Regression tests for the Folio config system (issue #2).
# ABOUTME: Covers AC2.1–AC2.5: YAML config loading, precedence merge, shared keys, front matter override.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TO_PDF="$PROJECT_DIR/org-play-to-pdf"
TO_MD="$PROJECT_DIR/org-play-to-markdown"
PASS=0
FAIL=0
FAILURES=()
TMPDIR_TEST="$(mktemp -d)"

cleanup() {
    # Restore real global config if we backed it up
    if [[ -f "$TMPDIR_TEST/global_config_backup/script.yaml" ]]; then
        mkdir -p "$HOME/.config/first-folio"
        cp "$TMPDIR_TEST/global_config_backup/script.yaml" "$HOME/.config/first-folio/script.yaml"
    elif [[ -f "$TMPDIR_TEST/global_config_was_absent" ]]; then
        rm -f "$HOME/.config/first-folio/script.yaml"
    fi
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

# --- Global config backup/restore helpers ---

backup_global_config() {
    if [[ -f "$HOME/.config/first-folio/script.yaml" ]]; then
        mkdir -p "$TMPDIR_TEST/global_config_backup"
        cp "$HOME/.config/first-folio/script.yaml" "$TMPDIR_TEST/global_config_backup/script.yaml"
    else
        touch "$TMPDIR_TEST/global_config_was_absent"
    fi
}

set_global_config() {
    mkdir -p "$HOME/.config/first-folio"
    cat > "$HOME/.config/first-folio/script.yaml"
}

remove_global_config() {
    rm -f "$HOME/.config/first-folio/script.yaml"
}

# --- Test fixtures ---

create_minimal_fixture() {
    cat > "$TMPDIR_TEST/minimal.org" <<'ORG'
#+TITLE: Test Play
#+AUTHOR: Test Author
#+SUBTITLE: Test Subtitle
#+TEMPLATE: play

* CHARACTERS
|------+-------------|
| BOB  | A test char |
| CÁIT | Another     |
|------+-------------|

* Act I
** Scene 1
*** A bare stage. Morning light.
**** BOB
Hello there.
*** BOB crosses to the window.
**** CÁIT softly
Goodbye now.
ORG
}

create_no_title_fixture() {
    cat > "$TMPDIR_TEST/no_title.org" <<'ORG'
* Act I
** Scene 1
*** A room.
**** BOB
Hello.
ORG
}

# ====================================================================
echo "=== Folio config system tests (issue #2) ==="

# Back up any existing global config before we start
backup_global_config

# --- AC2.1: Config loaded from script.yaml ---
echo ""
echo "AC2.1: Configuration is read from YAML files named script.yaml"

# RT-2.1: PDF output reflects font and margin values from a valid script.yaml
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
folio:
  font: "Georgia"
  margin: 40mm
YAML

remove_global_config
if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt21.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    found_font=false
    found_margin=false
    if grep -q "Georgia" "$TMPDIR_TEST/rt21.typ"; then found_font=true; fi
    if grep -q "40mm" "$TMPDIR_TEST/rt21.typ"; then found_margin=true; fi
    if $found_font && $found_margin; then
        pass "RT-2.1: PDF output reflects font and margin values from a valid script.yaml"
    else
        fail "RT-2.1: PDF output reflects font and margin values from a valid script.yaml" \
             "font=$found_font margin=$found_margin"
    fi
else
    fail "RT-2.1: PDF output reflects font and margin values from a valid script.yaml" \
         "Script exited non-zero"
fi

# RT-2.2: Malformed YAML halts with descriptive error
cat > "$TMPDIR_TEST/bad_script.yaml" <<'YAML'
folio:
  font: "Georgia
  margin: 40mm
YAML
# Copy to a subdir so we can place a malformed script.yaml alongside a source file
mkdir -p "$TMPDIR_TEST/bad_yaml_dir"
cp "$TMPDIR_TEST/minimal.org" "$TMPDIR_TEST/bad_yaml_dir/play.org"
cp "$TMPDIR_TEST/bad_script.yaml" "$TMPDIR_TEST/bad_yaml_dir/script.yaml"

remove_global_config
stderr_output=$("$TO_PDF" --typ-only -o "$TMPDIR_TEST/bad_out.typ" "$TMPDIR_TEST/bad_yaml_dir/play.org" 2>&1 1>/dev/null || true)
exit_code=0
"$TO_PDF" --typ-only -o "$TMPDIR_TEST/bad_out2.typ" "$TMPDIR_TEST/bad_yaml_dir/play.org" 2>/dev/null || exit_code=$?
if [[ "$exit_code" -ne 0 ]] && [[ -n "$stderr_output" ]]; then
    pass "RT-2.2: Malformed YAML halts with descriptive error on stderr and non-zero exit"
else
    fail "RT-2.2: Malformed YAML halts with descriptive error on stderr and non-zero exit" \
         "exit_code=$exit_code stderr='$stderr_output'"
fi

# --- AC2.2: Precedence order with layered merge ---
echo ""
echo "AC2.2: Config loads in precedence order with layered merge"

# RT-2.3: CLI flag overrides local script.yaml
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
folio:
  font: "Georgia"
YAML

remove_global_config
if "$TO_PDF" --typ-only --font "Palatino" -o "$TMPDIR_TEST/rt23.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Palatino" "$TMPDIR_TEST/rt23.typ"; then
        if ! grep -q '"Georgia"' "$TMPDIR_TEST/rt23.typ"; then
            pass "RT-2.3: CLI flag overrides the same key set in local script.yaml"
        else
            fail "RT-2.3: CLI flag overrides the same key set in local script.yaml" \
                 "Both Palatino and Georgia found — CLI did not fully override"
        fi
    else
        fail "RT-2.3: CLI flag overrides the same key set in local script.yaml" \
             "Palatino not found in output"
    fi
else
    fail "RT-2.3: CLI flag overrides the same key set in local script.yaml" \
         "Script exited non-zero"
fi

# RT-2.4: Local script.yaml overrides global script.yaml
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
folio:
  font: "Helvetica"
YAML

set_global_config <<'YAML'
folio:
  font: "Times New Roman"
YAML

if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt24.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Helvetica" "$TMPDIR_TEST/rt24.typ" && ! grep -q "Times New Roman" "$TMPDIR_TEST/rt24.typ"; then
        pass "RT-2.4: Local script.yaml overrides the same key set in global script.yaml"
    else
        fail "RT-2.4: Local script.yaml overrides the same key set in global script.yaml" \
             "Expected Helvetica only"
    fi
else
    fail "RT-2.4: Local script.yaml overrides the same key set in global script.yaml" \
         "Script exited non-zero"
fi

# RT-2.5: Global script.yaml overrides built-in defaults
create_minimal_fixture
rm -f "$TMPDIR_TEST/script.yaml"  # no local config

set_global_config <<'YAML'
folio:
  font: "Courier New"
YAML

if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt25.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Courier New" "$TMPDIR_TEST/rt25.typ"; then
        pass "RT-2.5: Global script.yaml overrides built-in defaults"
    else
        fail "RT-2.5: Global script.yaml overrides built-in defaults" \
             "Courier New not found in output"
    fi
else
    fail "RT-2.5: Global script.yaml overrides built-in defaults" \
         "Script exited non-zero"
fi

# RT-2.6: Keys from global that are not overridden by local remain in effect
create_minimal_fixture

set_global_config <<'YAML'
folio:
  font: "Times New Roman"
  page: letter
  margin: 35mm
YAML

cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
folio:
  font: "Georgia"
YAML

if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt26.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    found_local_font=false
    found_global_page=false
    found_global_margin=false
    found_old_font=false
    if grep -q "Georgia" "$TMPDIR_TEST/rt26.typ"; then found_local_font=true; fi
    if grep -qi "letter" "$TMPDIR_TEST/rt26.typ"; then found_global_page=true; fi
    if grep -q "35mm" "$TMPDIR_TEST/rt26.typ"; then found_global_margin=true; fi
    if grep -q "Times New Roman" "$TMPDIR_TEST/rt26.typ"; then found_old_font=true; fi
    if $found_local_font && $found_global_page && $found_global_margin && ! $found_old_font; then
        pass "RT-2.6: Keys from global config not overridden by local remain in effect (layers merge, not replace)"
    else
        fail "RT-2.6: Keys from global config not overridden by local remain in effect (layers merge, not replace)" \
             "local_font=$found_local_font global_page=$found_global_page global_margin=$found_global_margin old_font=$found_old_font"
    fi
else
    fail "RT-2.6: Keys from global config not overridden by local remain in effect (layers merge, not replace)" \
         "Script exited non-zero"
fi

# --- AC2.3: Shared keys and folio namespace ---
echo ""
echo "AC2.3: First Folio reads shared and folio: keys, ignores others"

# RT-2.7: Shared rendering keys control output content
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
render-stage-directions: false
render-character-table: false
YAML

remove_global_config

# Test with markdown (easier to inspect than Typst)
if "$TO_MD" "$TMPDIR_TEST/minimal.org" > "$TMPDIR_TEST/rt27.md" 2>/dev/null; then
    has_stage_dir=false
    has_char_table=false
    has_dialogue=false
    if grep -qi "bare stage" "$TMPDIR_TEST/rt27.md"; then has_stage_dir=true; fi
    if grep -q "A test char" "$TMPDIR_TEST/rt27.md"; then has_char_table=true; fi
    if grep -q "Hello there" "$TMPDIR_TEST/rt27.md"; then has_dialogue=true; fi
    if ! $has_stage_dir && ! $has_char_table && $has_dialogue; then
        pass "RT-2.7: Shared rendering keys control output content (stage directions and character table omitted)"
    else
        fail "RT-2.7: Shared rendering keys control output content" \
             "stage_dir=$has_stage_dir char_table=$has_char_table dialogue=$has_dialogue (expected false/false/true)"
    fi
else
    fail "RT-2.7: Shared rendering keys control output content" \
         "Script exited non-zero"
fi

# RT-2.8: Unknown top-level keys cause no errors or warnings
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
title: "Test Play"
character-voices:
  KEVIN: af_alloy
  NESSA: af_heart
narrator-voice: bf_alice
auto-assign-voices: true
dialogue-speed: 1.0
speech-substitution:
  Cáit: Kawch
folio:
  font: "Georgia"
YAML

remove_global_config
stderr_out=$("$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt28.typ" "$TMPDIR_TEST/minimal.org" 2>&1 1>/dev/null)
exit_code=0
"$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt28b.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null || exit_code=$?
if [[ "$exit_code" -eq 0 ]] && [[ -z "$stderr_out" ]]; then
    pass "RT-2.8: Unknown top-level keys (character-voices, narrator-voice, etc.) cause no errors or warnings"
else
    fail "RT-2.8: Unknown top-level keys cause no errors or warnings" \
         "exit_code=$exit_code stderr='$stderr_out'"
fi

# --- AC2.4: Deprecated config not read ---
echo ""
echo "AC2.4: Deprecated flat config at ~/.config/org-script/config is not read"

# RT-2.9: Deprecated config has no effect when no script.yaml exists
create_minimal_fixture
rm -f "$TMPDIR_TEST/script.yaml"
remove_global_config

# Create deprecated config with a distinctive font
mkdir -p "$HOME/.config/org-script"
cat > "$HOME/.config/org-script/config" <<'CONF'
font = Zapfino
CONF

if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt29.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Zapfino" "$TMPDIR_TEST/rt29.typ"; then
        fail "RT-2.10: Deprecated flat config has no effect on output when no script.yaml exists" \
             "Zapfino found — deprecated config is still being read"
    else
        pass "RT-2.10: Deprecated flat config has no effect on output when no script.yaml exists"
    fi
else
    # Non-zero exit is also acceptable — as long as Zapfino isn't used
    if [[ -f "$TMPDIR_TEST/rt29.typ" ]] && grep -q "Zapfino" "$TMPDIR_TEST/rt29.typ"; then
        fail "RT-2.10: Deprecated flat config has no effect on output when no script.yaml exists" \
             "Zapfino found — deprecated config is still being read"
    else
        pass "RT-2.10: Deprecated flat config has no effect on output when no script.yaml exists"
    fi
fi

# RT-2.11: No warning or error emitted about deprecated config
stderr_out=$("$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt211.typ" "$TMPDIR_TEST/minimal.org" 2>&1 1>/dev/null || true)
if [[ -z "$stderr_out" ]]; then
    pass "RT-2.11: No warning or error is emitted about the deprecated config location"
else
    fail "RT-2.11: No warning or error is emitted about the deprecated config location" \
         "stderr='$stderr_out'"
fi

# Clean up deprecated config
rm -f "$HOME/.config/org-script/config"

# --- AC2.5: Config metadata overrides source document ---
echo ""
echo "AC2.5: Config metadata overrides source document values"

# RT-2.12: Config title overrides source file #+TITLE
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
title: "Override Title"
YAML

remove_global_config

# Test in both PDF and Markdown output
if "$TO_MD" "$TMPDIR_TEST/minimal.org" > "$TMPDIR_TEST/rt212.md" 2>/dev/null; then
    if grep -q "Override Title" "$TMPDIR_TEST/rt212.md" && ! grep -q "Test Play" "$TMPDIR_TEST/rt212.md"; then
        pass "RT-2.12: Config title overrides source file #+TITLE in Markdown output"
    else
        fail "RT-2.12: Config title overrides source file #+TITLE in Markdown output" \
             "Expected 'Override Title' only, not 'Test Play'"
    fi
else
    fail "RT-2.12: Config title overrides source file #+TITLE in Markdown output" \
         "Script exited non-zero"
fi

# Also verify in Typst output
if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt212.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Override Title" "$TMPDIR_TEST/rt212.typ" && ! grep -q "Test Play" "$TMPDIR_TEST/rt212.typ"; then
        # Additional PDF check passes (not counted separately, supplements RT-2.12)
        :
    else
        fail "RT-2.12 (PDF): Config title overrides source file #+TITLE in PDF output" \
             "Expected 'Override Title' only in Typst source"
    fi
fi

# RT-2.13: Source #+TITLE used when config has no title
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
folio:
  font: "Georgia"
YAML

remove_global_config
if "$TO_MD" "$TMPDIR_TEST/minimal.org" > "$TMPDIR_TEST/rt213.md" 2>/dev/null; then
    if grep -q "Test Play" "$TMPDIR_TEST/rt213.md"; then
        pass "RT-2.13: Source file #+TITLE is used when config has no title key"
    else
        fail "RT-2.13: Source file #+TITLE is used when config has no title key" \
             "Test Play not found in output"
    fi
else
    fail "RT-2.13: Source file #+TITLE is used when config has no title key" \
         "Script exited non-zero"
fi

# RT-2.14: Config subtitle overrides source file #+SUBTITLE
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
subtitle: "Override Subtitle"
YAML

remove_global_config
if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt214.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "Override Subtitle" "$TMPDIR_TEST/rt214.typ" && ! grep -q "Test Subtitle" "$TMPDIR_TEST/rt214.typ"; then
        pass "RT-2.14: Config subtitle overrides source file #+SUBTITLE in PDF output"
    else
        fail "RT-2.14: Config subtitle overrides source file #+SUBTITLE in PDF output" \
             "Expected 'Override Subtitle' only"
    fi
else
    fail "RT-2.14: Config subtitle overrides source file #+SUBTITLE in PDF output" \
         "Script exited non-zero"
fi

# RT-2.15: Config draft-date appears on the PDF title page
create_minimal_fixture
cat > "$TMPDIR_TEST/script.yaml" <<'YAML'
draft-date: "2026-04-26"
YAML

remove_global_config
if "$TO_PDF" --typ-only -o "$TMPDIR_TEST/rt215.typ" "$TMPDIR_TEST/minimal.org" 2>/dev/null; then
    if grep -q "2026-04-26" "$TMPDIR_TEST/rt215.typ"; then
        pass "RT-2.15: Config draft-date appears on the PDF title page"
    else
        fail "RT-2.15: Config draft-date appears on the PDF title page" \
             "2026-04-26 not found in Typst output"
    fi
else
    fail "RT-2.15: Config draft-date appears on the PDF title page" \
         "Script exited non-zero"
fi

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
