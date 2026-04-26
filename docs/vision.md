<!-- Version: 0.1 | Last updated: 2026-04-26 -->

# First Folio - Vision

## Purpose

First Folio is a format converter for stage plays. It reads plays written in a structured source format and produces output in any supported target format, preserving the semantic structure of the work: acts, scenes, stage directions, character names, dialogue, character tables, and front matter.

## Name

The name references the 1623 First Folio of Shakespeare's plays - the first collected edition that preserved works which might otherwise have been lost. This tool serves a similar role: taking a play in one format and faithfully rendering it in another.

## Problem

Playwrights and dramaturgs work across multiple tools and workflows. A play may be drafted in Emacs org-mode, submitted in Fountain format, typeset as PDF for rehearsal, or published as Markdown. No single tool handles all of these conversions while preserving the semantic structure of the text. Existing converters (pandoc, etc.) treat plays as generic documents, losing the distinction between stage directions, character names, dialogue, and other dramatic elements.

## Goals

1. **Format-agnostic internal representation.** The parser emits a stream of typed semantic events (act, scene, stage direction, character, dialogue, etc.). Output backends consume these events and produce format-specific output. Adding a new format means writing a new parser or a new emitter - not modifying existing code.

2. **Lossless round-tripping where possible.** Converting from format A to format B and back should preserve the semantic content of the play. Formatting details (whitespace, indentation) may change, but no acts, scenes, directions, characters, or dialogue lines should be lost.

3. **Faithful formatting.** Each output format follows its own conventions. Markdown uses headers and bold/italic. PDF (via Typst) uses British stage play layout with proper indentation. Fountain follows the Fountain markup specification. The tool does not impose one format's conventions on another.

4. **CLI-first, scriptable.** All operations are available as command-line tools that read from files or stdin and write to files or stdout. Batch processing, piping, and scripting are first-class use cases.

5. **Minimal dependencies.** Core conversion requires only Perl and its standard library. PDF output requires Typst. No other external tools are needed.

## Supported Formats

| Format | Read | Write | Notes |
|--------|------|-------|-------|
| Org-mode play | Yes | No | Structured org with heading-level semantics |
| Markdown | No | Yes | Clean idiomatic Markdown |
| PDF | No | Yes | Via Typst, British stage play layout |
| Fountain | Planned | Planned | Industry-standard screenplay/stage play format |

The direction of travel is toward full read/write support for all text-based formats (org, Markdown, Fountain). PDF remains write-only as it is a final-output format.

## Non-goals

- **Word processor formats.** DOCX, ODT, and similar formats are out of scope. Use pandoc to convert Markdown output if needed.
- **Screenplay-specific features.** First Folio targets stage plays, not screenplays. Fountain's screenplay-specific elements (camera directions, transitions) are accepted on input but may not be preserved on output.
- **GUI.** First Folio is a CLI tool. There are no plans for a graphical interface.
- **Content editing.** First Folio converts between formats. It does not provide editing, linting, or structural validation of play content.
