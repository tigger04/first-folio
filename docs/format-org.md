sanitize: defaulting to oed + symbols
<!-- Version: 0.1 | Last updated: 2026-04-26 -->

# Org-mode Play Format

Org-mode is the primary authoring format for First Folio. It uses Emacs org-mode heading levels to encode the hierarchical structure of a stage play. This format supports all event-stream elements without loss.

**External reference:** [orgmode.org - Document Structure](https://orgmode.org/manual/Document-Structure.html)

## Element Schema

### Front Matter

Org-mode keyword lines at the top of the file. Any `#+KEY: value` line is captured.

```org
#+TITLE: The Importance of Being Earnest
#+AUTHOR: Oscar Wilde
#+SUBTITLE: A Trivial Comedy for Serious People
#+TEMPLATE: play
```

Standard keys: `TITLE`, `AUTHOR`, `SUBTITLE`. Any key is accepted and passed through the event stream.

### Acts (H1)

Level-1 headings represent acts. The heading text becomes the act title.

```org
* Act I
* Act II
* Epilogue
```

The special heading `* CHARACTERS` (case-insensitive, singular or plural) is not an act - it introduces a character table (see below).

### Scenes (H2)

Level-2 headings represent scenes within an act.

```org
** Scene 1
** Scene 2 — The Garden
```

### Stage Directions (H3)

Level-3 headings represent stage directions (also called action text or narrative). These describe setting, movement, and physical action.

```org
*** A morning room in Algernon's flat in Half-Moon Street.
*** JACK enters through the French windows.
```

Org-mode inline markup within stage directions is converted: `/italic/` -> italic, `*bold*` -> bold.

### Characters (H4)

Level-4 headings introduce a character who is about to speak. The heading contains the character name in ALL CAPS, optionally followed by a parenthetical direction.

```org
**** ALGERNON
**** JACK earnestly
**** LADY BRACKNELL (rising)
**** GWENDOLEN, with great feeling
```

All of the following direction formats are normalized to the same internal representation:

| Syntax | Name | Direction |
|--------|------|-----------|
| `**** BOB softly` | BOB | softly |
| `**** BOB (softly)` | BOB | softly |
| `**** BOB, softly` | BOB | softly |
| `**** BOB, (softly)` | BOB | softly |
| `**** BOB` | BOB | (none) |

Character names support Unicode: `CÁIT`, `MAIRÉAD`, `SÉAN`.

### Dialogue

Plain text following an H4 heading. Multiple lines are preserved. Blank lines are consumed silently.

```org
**** ALGERNON
I don't think there is much likelihood, Jack,
of you and Miss Fairfax being united.
```

Org-mode inline markup within dialogue is converted: `/italic/` -> italic, `*bold*` -> bold.

### Character Table

A level-1 heading `* CHARACTERS` (or `* CHARACTER`) followed by an org table listing the cast.

```org
* CHARACTERS
|----------+------------------------------|
| ALGERNON | A young man about town       |
| JACK     | His friend, also young       |
| LANE     | Algernon's manservant        |
|----------+------------------------------|
```

Separator rows (`|---+---|`) are ignored. Each data row emits a `character_table_row` event with the name and description.

### Prop Text

On-stage text (signs, letters, placards) marked with a specific list-item pattern.

```org
- *"WELCOME TO THE GARDEN PARTY"*
```

The pattern is: `- *"TEXT"*` - a list item containing bold-quoted text. The quotes and bold markers are stripped; only the inner text is emitted.

### Footnotes

Org-mode footnote definitions. The reference `[fn:name]` appears inline in dialogue or directions; the definition appears on its own line.

```org
[fn:verse] From Tennyson's "In Memoriam", Canto 27.
```

### Noexport Sections

Any heading tagged `:noexport:` is excluded from output, along with all its children.

```org
*** Notes on staging :noexport:
These are private notes and will not appear in any output.
```

## Complete Example

```org
#+TITLE: A Short Play
#+AUTHOR: A. Playwright

* CHARACTERS
|------+------------------|
| BOB  | An ordinary man  |
| CÁIT | His neighbour    |
|------+------------------|

* Act I
** Scene 1
*** A kitchen. Morning. Sunlight through the window.
**** BOB
Good morning.

*** BOB crosses to the kettle.

**** CÁIT (entering)
Is the kettle on?

**** BOB cheerfully
Just boiled.

*** Research notes :noexport:
- Look up kettle brands for period accuracy.
```
1 -ize correction
7 symbol replacements
