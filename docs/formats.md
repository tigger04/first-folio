sanitize: defaulting to oed + symbols
<!-- Version: 0.1 | Last updated: 2026-04-26 -->

# Format Overview

First Folio converts stage plays between three text-based formats (org-mode, Markdown, Fountain) and one output-only format (PDF). All conversions pass through a shared **event stream** - a sequence of typed semantic events representing the structure of a play. Each format has an independent parser (reader) and emitter (writer); no direct format-to-format conversion paths exist.

## Supported Formats

| Format | Read | Write | Reference |
|--------|------|-------|-----------|
| [Org-mode play](format-org.md) | Yes | Yes | [orgmode.org](https://orgmode.org) |
| [Markdown play](format-markdown.md) | Yes | Yes | [CommonMark](https://commonmark.org) |
| [Fountain](format-fountain.md) | Yes | Yes | [fountain.io](https://fountain.io) |
| PDF (via Typst) | - | Yes | [typst.app](https://typst.app) |

## The Event Stream

The event stream is the intermediate representation. Every parser emits these events; every emitter consumes them. The events correspond to the semantic elements of a stage play:

| Event | Arguments | Meaning |
|-------|-----------|---------|
| `front_matter` | key, value | Metadata (title, author, etc.) |
| `act_header` | title | Start of an act |
| `scene_header` | title | Start of a scene |
| `stage_direction` | text | Narrative/action text between dialogue |
| `character` | name, direction | Character about to speak, with optional parenthetical |
| `dialogue` | line | A line of speech |
| `character_table_start` | - | Begin cast list |
| `character_table_row` | name, description | One entry in the cast list |
| `character_table_end` | - | End cast list |
| `prop_text` | text | On-stage text (signs, placards, letters read aloud) |
| `footnote_def` | name, text | A footnote definition |
| `end` | - | End of document |

## Fidelity Matrix

Not every format can represent every event natively. The matrix below shows which events survive each format. **Lossless** means the element round-trips without degradation. **Degraded** means the content is preserved but structural metadata is lost. **Lost** means the element cannot be represented and is dropped.

| Event | Org-mode | Markdown | Fountain | PDF |
|-------|----------|----------|----------|-----|
| front_matter (title) | Lossless | Lossless | Lossless | Lossless |
| front_matter (author) | Lossless | Lossless | Lossless | Lossless |
| front_matter (other keys) | Lossless | Lost | Lossless | Lost |
| act_header | Lossless | Lossless | Degraded | Lossless |
| scene_header | Lossless | Lossless | Lossless | Lossless |
| stage_direction | Lossless | Lossless | Lossless | Lossless |
| character | Lossless | Lossless | Lossless | Lossless |
| character (direction) | Lossless | Lossless | Lossless | Lossless |
| dialogue | Lossless | Lossless | Lossless | Lossless |
| character_table | Lossless | Lossless | Degraded | Lossless |
| prop_text | Lossless | Lossless | Degraded | Lossless |
| footnote_def | Lossless | Lossless | Degraded | Lossless |

### Key Fidelity Gaps

Fountain is the format with the most fidelity concerns. See [format-fountain.md §Fidelity Analysis](format-fountain.md#fidelity-analysis) for full details. In summary:

- **Act headers** map to Fountain Sections, which are invisible in formatted output - they serve as structural markers only. A Fountain reader can recover them, but a human reading a formatted Fountain document cannot see act boundaries.
- **Character tables** have no Fountain equivalent. They are rendered as plain Action text, which means a Fountain->org round-trip loses the table structure.
- **Prop text** maps to Fountain's centred text (`>TEXT<`), which loses the semantic distinction between "on-stage text" and "centred action".
- **Footnotes** map to Fountain Notes (`[[text]]`), which are not numbered and are invisible in formatted output. The name/number of the footnote is lost.

Markdown's only fidelity gap is arbitrary front matter keys - Markdown output includes only title and author.
8 symbol replacements
