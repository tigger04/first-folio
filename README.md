# First Folio

A format converter for stage plays. Reads plays in structured source formats and produces output in multiple target formats, preserving the semantic structure: acts, scenes, stage directions, characters, dialogue, and front matter.

## Quickstart

```bash
# Convert an org-mode play to Markdown
folio convert play.org play.md

# Convert to PDF (requires Typst)
folio convert play.org play.pdf

# Convert to Fountain
folio convert play.org play.fountain

# Output to stdout
folio convert play.org --to md

# Convert between any supported formats
folio convert play.fountain play.md
folio convert play.md play.org
```

## Installation

```bash
make install    # symlinks folio to ~/.local/bin/
make uninstall  # removes the symlink
```

### Dependencies

- **Perl 5** (core modules only - no CPAN dependencies)
- **Typst** (required only for PDF output)

## Supported Formats

| Format | Read | Write | Schema |
|--------|------|-------|--------|
| Org-mode | Yes | Yes | [docs/format-org.md](docs/format-org.md) |
| Markdown | Yes | Yes | [docs/format-markdown.md](docs/format-markdown.md) |
| Fountain | Yes | Yes | [docs/format-fountain.md](docs/format-fountain.md) |
| PDF (via Typst) | - | Yes | - |

Org-mode uses heading levels to encode play structure. Markdown uses headers, bold, and italic conventions. Fountain follows the [Fountain spec](https://fountain.io/syntax). See the schema docs for full element mappings, and [docs/formats.md](docs/formats.md) for the event stream and fidelity matrix.

**Intro sections** (Synopsis, Setting, Scene List, etc.) are automatically distinguished from the play proper. Any headers and prose before the first character dialogue are treated as intro material and can be toggled on/off via `render-intro` in config.

## Configuration

First Folio reads configuration from `script.yaml` files. It never creates or modifies config files.

```yaml
# ~/.config/first-folio/script.yaml or alongside your source file

date: "2026-04-26"
version: "Draft v3"

folio:
  font: EB Garamond
  font-size: 11pt
  page: a4
```

All config sources are merged in precedence order: CLI flags > local `script.yaml` > global `script.yaml` > built-in defaults. The config file is shared with [yapper](https://github.com/tigger04/yapper) (TTS rendering).

See [docs/config.md](docs/config.md) for the full schema and [examples/script.yaml](examples/script.yaml) for a complete annotated example.

## Project Structure

| Path | Purpose |
|------|---------|
| `bin/folio` | Unified CLI with `convert` subcommand |
| `lib/Folio/Parser/` | Format parsers (Org, Markdown, Fountain) |
| `lib/Folio/Emitter/` | Format emitters (Org, Markdown, Fountain, Typst/PDF) |
| `lib/Folio/Config.pm` | Config loading with layered merge |
| `lib/Folio/Format.pm` | Extension and format mapping |
| `lib/OrgPlay/` | Shared parser and Typst template (legacy namespace) |
| `tests/regression/` | Regression test suite (run via `make test`) |
| `tests/one_off/` | One-off tests for specific issues |
| `examples/` | Annotated config example |
| `docs/` | Format schemas, config reference, vision |

## Running Tests

```bash
make test           # regression suite
make test-one-off   # all one-off tests
make test-one-off ISSUE=5  # one-off tests for a specific issue
```

## Documentation

- [Vision](docs/vision.md) - project goals, supported formats, and direction of travel
- [Configuration](docs/config.md) - config schema, precedence, shared keys, migration
- [Formats](docs/formats.md) - format overview, event stream, and fidelity matrix
  - [Org-mode](docs/format-org.md) - org-mode play format schema
  - [Markdown](docs/format-markdown.md) - Markdown play format schema
  - [Fountain](docs/format-fountain.md) - Fountain format schema and fidelity analysis

## Licence

MIT - Copyright Taḋg Paul

## Acknowledgements

- [YAML::Tiny](https://metacpan.org/pod/YAML::Tiny) v1.76 by Adam Kennedy — embedded YAML parser. Licensed under the same terms as Perl itself (Artistic License 1.0 / GPL 1+).
