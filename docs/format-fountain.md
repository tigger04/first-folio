sanitize: defaulting to oed + symbols
<!-- Version: 0.1 | Last updated: 2026-04-26 -->

# Fountain Format

Fountain is a plain-text markup language designed primarily for screenplays. It is also used for stage plays, though some of its conventions are screenplay-centric. First Folio supports Fountain as both an input and output format, with documented fidelity limitations.

**External references:**
- [fountain.io](https://fountain.io) - official site, specification, and apps
- [Fountain Syntax](https://fountain.io/syntax) - full syntax reference
- [Fountain Apps](https://fountain.io/apps) - editors and tools that support Fountain

## Why Fountain Matters

Fountain is widely supported by professional screenwriting and playwriting software (Highland, Slugline, Fade In, WriterSolo, and others). It is the closest thing to an industry standard for plain-text dramatic writing. Supporting Fountain allows First Folio to interoperate with these tools and their ecosystems.

## Element Schema

### Title Page

Key-value pairs at the very start of the file. Keys end with a colon. Values are either inline or indented on the next line (3+ spaces or tab). The title page is terminated by two consecutive blank lines.

```fountain
Title: The Importance of Being Earnest
Author: Oscar Wilde
Draft date: 1895
Contact:
    oscar@example.com
    +44 20 7946 0958

```

Common keys: `Title`, `Credit`, `Author`, `Authors`, `Source`, `Draft date`, `Contact`, `Copyright`, `Notes`. Any key is accepted.

**Event mapping:** Each key-value pair -> `front_matter(key, value)`.

### Sections

Structural markers using ATX-style headings. Sections are **invisible** in formatted Fountain output - they exist purely for organizational purposes in the plain-text source.

```fountain
# Act I
## Act I, Scene 1
### Subplot A
```

**Event mapping:** `#` -> `act_header(title)`. `##` -> `scene_header(title)`. Deeper levels are collapsed to `scene_header`.

**Fidelity note:** This is a key difference from org-mode and Markdown, where act/scene headers are visible structural elements. In Fountain, sections are metadata. A human reading a Fountain document in a Fountain app will not see section headings in the formatted output - they appear only in the outline/navigator. See [Fidelity Analysis §Act Headers](#act-headers) below.

### Scene Headings

Lines beginning with `INT`, `EXT`, `EST`, `INT./EXT`, `INT/EXT`, or `I/E` (case-insensitive). Any line can be forced as a scene heading by prefixing with a period (`.`).

```fountain
INT. ALGERNON'S FLAT - MORNING

.Scene 1 — The Morning Room
```

Scene headings must be preceded by a blank line. Optional scene numbers can be appended: `INT. FLAT - MORNING #1#`.

**Event mapping:** -> `scene_header(title)`. The period prefix is stripped. `INT`/`EXT` prefixes are preserved in the title text.

**Fidelity note:** Fountain scene headings are screenplay-oriented (INT/EXT locations). For stage plays, the forced syntax (`.Scene 1`) is more natural. When emitting Fountain from a stage play, scene headers are written with the forced-heading syntax to avoid requiring INT/EXT prefixes.

### Action

Any paragraph that does not match another element type. This is Fountain's default - unrecognized text becomes Action. A line can be forced as Action by prefixing with `!`.

```fountain
A morning room in Algernon's flat in Half-Moon Street.
The room is luxuriously furnished.

!JACK enters — this is forced Action despite being all-caps.
```

Leading tabs and spaces are preserved (tabs = 4 spaces). Blank lines within an Action block are preserved.

**Event mapping:** -> `stage_direction(text)`.

### Character

A line entirely in UPPERCASE, preceded by a blank line, not followed by a blank line. Must contain at least one alphabetical character. Parenthetical extensions are allowed on the same line.

```fountain
ALGERNON

JACK (O.S.)

LADY BRACKNELL (V.O.)
```

A character name can be forced to preserve mixed case by prefixing with `@`:

```fountain
@McCLANE
```

**Event mapping:** -> `character(name, undef)`. Character extensions like `(O.S.)` and `(V.O.)` are screenplay conventions (off-screen, voice-over) and are treated as parenthetical directions.

### Parenthetical

Text wrapped in parentheses, appearing after a Character or Dialogue element.

```fountain
ALGERNON
(languidly)
I really don't see anything romantic in proposing.
```

**Event mapping:** The parenthetical is captured as the `direction` argument of the preceding `character` event. If the parenthetical appears mid-dialogue (after dialogue text rather than immediately after the character name), it is emitted as inline text within the dialogue - the event stream does not support mid-dialogue parentheticals.

**Fidelity note:** Fountain allows parentheticals between lines of dialogue (mid-speech direction changes). The event stream only supports a single direction at the start of a character's speech. Mid-dialogue parentheticals are flattened into the dialogue text on import. See [Fidelity Analysis §Mid-dialogue Parentheticals](#mid-dialogue-parentheticals).

### Dialogue

Text following a Character or Parenthetical element. Continues until a blank line.

```fountain
ALGERNON
I really don't see anything romantic in proposing.
It is very romantic to be in love.
```

Manual line breaks within dialogue are preserved. To include an intentional blank line within dialogue (without ending the dialogue block), use a line containing only two spaces.

**Event mapping:** Each line -> `dialogue(line)`.

### Dual Dialogue

Two characters speaking simultaneously. Indicated by appending `^` to the second Character name.

```fountain
JACK
I have lost my handbag.

ALGERNON ^
You have lost your handbag?!
```

**Event mapping:** Dual dialogue has **no equivalent** in the event stream. When reading Fountain, dual dialogue is parsed as two sequential character/dialogue blocks - the simultaneity marker is lost. When writing Fountain, dual dialogue is never emitted (the event stream cannot represent it).

**Fidelity note:** This is a **complete loss**. See [Fidelity Analysis §Dual Dialogue](#dual-dialogue).

### Transition

Uppercase text ending in `TO:`, preceded and followed by blank lines. Can be forced with `>` prefix.

```fountain
CUT TO:

>FADE OUT.
```

**Event mapping:** -> `stage_direction(text)`. The semantic distinction between a transition and a stage direction is lost. Transitions are a screenplay convention and are uncommon in stage plays.

### Lyrics

Lines prefixed with `~`. Used for songs within dialogue.

```fountain
~It is a truth universally acknowledged
~that a single man in possession of a good fortune
~must be in want of a wife.
```

**Event mapping:** -> `dialogue(line)` with the `~` prefix stripped. The lyric/song marker is lost.

**Fidelity note:** Lyrics lose their semantic marking. On round-trip, song lyrics become ordinary dialogue.

### Centred Text

Action text bracketed with `><`.

```fountain
>THE END<

>INTERMISSION<
```

**Event mapping:** -> `prop_text(text)`.

### Notes

Text enclosed in double brackets. Invisible in formatted output.

```fountain
[[This scene needs more tension — revisit in next draft.]]
```

Notes can appear inline within other elements or on their own line. They can span multiple lines.

**Event mapping:** -> `footnote_def(name, text)`. The name is auto-generated since Fountain notes are not numbered.

**Fidelity note:** Org-mode and Markdown footnotes are numbered/named and appear in the output. Fountain notes are anonymous and invisible. The name is lost on Fountain export; the content is preserved but becomes invisible. See [Fidelity Analysis §Footnotes](#footnotes).

### Synopses

Lines prefixed with `=`. Invisible in formatted output. Used for outlining.

```fountain
= Jack arrives and reveals his secret identity.
```

**Event mapping:** **Dropped.** Synopses have no event-stream equivalent. They are consumed by the Fountain parser and discarded.

**Fidelity note:** Synopses exist only in Fountain. They are **completely lost** on import.

### Boneyard (Comments)

Text wrapped in `/* */`. Completely ignored.

```fountain
/* This whole scene might get cut. */
```

**Event mapping:** **Dropped.** Comments are consumed and discarded by the parser.

### Page Breaks

A line of three or more equals signs (`===`).

```fountain
===
```

**Event mapping:** **Dropped.** Page breaks have no event-stream equivalent.

### Emphasis

Fountain uses Markdown-style emphasis, plus underline:

| Syntax | Rendering |
|--------|-----------|
| `*italic*` | italic |
| `**bold**` | bold |
| `***bold italic***` | bold italic |
| `_underline_` | underline |

Emphasis does **not** carry across line breaks. Backslash (`\`) escapes special characters.

**Fidelity note:** Underline (`_text_`) has no equivalent in org-mode or Markdown. It is converted to italic on export to those formats.

---

## Fidelity Analysis

This section details every case where converting to or from Fountain loses information. Understanding these gaps is essential for choosing when Fountain is the right format and when it is not.

### Summary Table

| Element | Fountain -> Event Stream | Event Stream -> Fountain | Round-trip Impact |
|---------|------------------------|------------------------|-------------------|
| Title/Author | Lossless | Lossless | None |
| Other front matter keys | Lossless | Lossless | None |
| Act headers | Lossless (sections recoverable) | Degraded (invisible in output) | Visible -> invisible -> visible |
| Scene headers | Lossless | Lossless | None |
| Stage directions | Lossless | Lossless | None |
| Characters | Lossless | Lossless | None |
| Character directions | Lossless (initial only) | Lossless | None |
| Mid-dialogue parentheticals | Degraded (flattened to dialogue) | N/A (cannot emit) | **Lost** |
| Dialogue | Lossless | Lossless | None |
| Dual dialogue | **Lost** (becomes sequential) | N/A (cannot emit) | **Lost** |
| Character tables | N/A (no Fountain equivalent) | Degraded (becomes Action) | **Lost** on round-trip |
| Prop text | Lossless (centred text) | Degraded (becomes centred text) | Semantic distinction lost |
| Footnotes | Degraded (anonymous, invisible) | Degraded (name lost, invisible) | Name/numbering **lost** |
| Lyrics | Degraded (marker stripped) | N/A (cannot emit) | **Lost** |
| Synopses | **Lost** | N/A (cannot emit) | **Lost** |
| Boneyard | **Lost** | N/A (cannot emit) | **Lost** |
| Page breaks | **Lost** | N/A (cannot emit) | **Lost** |
| Underline emphasis | Degraded (becomes italic) | N/A | Underline -> italic |

### Act Headers

**The problem:** Fountain Sections (`#`, `##`) are invisible in formatted output. They exist as organizational metadata in the plain-text source and appear in the app's outline/navigator panel, but they are not rendered in the printed or exported document. In contrast, org-mode H1 headings and Markdown H2 headings are visible structural elements.

**On import (Fountain -> events):** Section headings are parsed and emitted as `act_header` events. No information is lost at the data level.

**On export (events -> Fountain):** Act headers are written as Section headings (`# Act I`). The text is preserved, but a reader viewing the formatted Fountain output will not see the act boundaries. Only someone reading the raw `.fountain` file or using an app's outline view will see them.

**Round-trip (org -> Fountain -> org):** The act header text survives, but the visual prominence changes: visible header -> invisible section -> visible header. Functionally lossless; visually degraded in the Fountain intermediate.

**Recommendation:** For plays where act structure is important to the reader (most stage plays), be aware that Fountain's formatted output will not show act divisions. This is a fundamental design decision in the Fountain spec, not a limitation of First Folio.

### Mid-dialogue Parentheticals

**The problem:** Fountain allows parenthetical directions between lines of dialogue:

```fountain
ALGERNON
I really don't see anything romantic in proposing.
(rises)
It is very romantic to be in love.
```

The event stream supports only a single `direction` at the start of a character's speech (`character(name, direction)`). There is no event for mid-speech stage directions.

**On import (Fountain -> events):** The initial parenthetical (if any) becomes the character's direction. Subsequent parentheticals are emitted as part of the dialogue text, wrapped in parentheses: `dialogue("(rises)")`. The semantic distinction between dialogue and direction is lost.

**On export (events -> Fountain):** The event stream cannot represent mid-dialogue parentheticals, so they are never emitted. If a play was originally written in Fountain with mid-dialogue parentheticals, importing and re-exporting it will flatten them into dialogue text.

**Impact:** Low for most stage plays. Mid-dialogue parentheticals are more common in screenplays. In stage play convention, a direction change mid-speech is typically written as a separate stage direction between two dialogue blocks.

### Dual Dialogue

**The problem:** Fountain's dual dialogue (`^` marker) indicates two characters speaking simultaneously. The event stream has no concept of simultaneous speech - events are sequential.

**On import:** The `^` marker is discarded. The two characters and their dialogue are emitted as sequential events.

**On export:** Dual dialogue is never emitted. There is no way to reconstruct simultaneity from sequential events.

**Impact:** Significant for screenplays; rare in stage plays. Stage plays typically indicate simultaneous speech through stage directions ("*They speak at once*") rather than typographic formatting.

### Character Tables

**The problem:** Character tables (cast lists with names and descriptions) are a feature of org-mode and Markdown. Fountain has no equivalent.

**On export (events -> Fountain):** Character table events are rendered as an Action block - plain text with the character names and descriptions formatted readably. The structured table format is lost.

**On import (Fountain -> events):** Fountain documents do not contain character tables, so no character table events are emitted. If a First Folio-generated Fountain file includes a cast list as an Action block, the parser cannot recover the table structure - it will be imported as a stage direction.

**Round-trip (org -> Fountain -> org):** The cast list goes from structured table to plain text to stage direction. The character names and descriptions survive as text, but the table structure is **permanently lost**.

**Recommendation:** If preserving the cast list structure is important, avoid Fountain as an intermediate format. Convert directly between org-mode, Markdown, and PDF.

### Footnotes

**The problem:** Org-mode footnotes (`[fn:name]`) and Markdown footnotes (`[^name]`) are named/numbered and appear as visible footnotes in the output. Fountain Notes (`[[text]]`) are anonymous and invisible in formatted output.

**On export (events -> Fountain):** Footnote content is preserved inside `[[note]]` markers, but the name/number is lost. The note becomes invisible in formatted Fountain output.

**On import (Fountain -> events):** Notes are emitted as `footnote_def` events with auto-generated names. The original anonymous nature of Fountain notes means there is no name to recover.

**Round-trip:** The footnote text survives, but the name/numbering is lost and the footnote changes from visible to invisible to visible (with a new auto-generated name).

### Lyrics, Synopses, Boneyard, Page Breaks

These are Fountain-only elements with no equivalent in the event stream.

**Lyrics (`~`):** Imported as dialogue with the lyric marker stripped. On round-trip, song lyrics become ordinary dialogue - the reader can no longer distinguish sung text from spoken text.

**Synopses (`=`):** Dropped entirely on import. These are outlining metadata.

**Boneyard (`/* */`):** Dropped entirely on import. These are authoring comments.

**Page breaks (`===`):** Dropped entirely on import. Page layout is handled by the output format (PDF via Typst).

None of these elements can be emitted from the event stream, so they exist only in source Fountain documents.

## Complete Example

```fountain
Title: A Short Play
Author: A. Playwright
Draft date: 2026

# Act I

.Scene 1

A kitchen. Morning. Sunlight through the window.

BOB
Good morning.

BOB crosses to the kettle.

CÁIT
(entering)
Is the kettle on?

BOB
(cheerfully)
Just boiled.

>THE END<
```
3 -ize corrections
43 symbol replacements
