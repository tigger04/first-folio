# ABOUTME: Fountain format parser — line-by-line state machine for screenplay/stage play markup.
# ABOUTME: Handles title pages, sections, scene headings, characters, parentheticals, dialogue.
package Folio::Parser::Fountain;

use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

our $VERSION = '0.1.0';

sub parse {
    my ($class, $fh, $emitter, %opts) = @_;

    my $warn_fh   = $opts{warn_fh} || \*STDERR;
    my $file_path = $opts{file_path} // '<stdin>';

    my $emit = sub {
        my ($event, @args) = @_;
        if (my $cb = $emitter->{$event}) {
            $cb->(@args);
        }
    };

    my $warn = sub {
        my ($line_num, $msg) = @_;
        print $warn_fh "warning: $file_path:$line_num: $msg\n";
    };

    # Read all lines for lookahead
    my @lines;
    while (my $line = <$fh>) {
        chomp $line;
        push @lines, $line;
    }

    my $i = 0;
    my $total = scalar @lines;

    # --- Title page ---
    # Title page is key: value pairs at the start, terminated by a blank line
    if ($total > 0 && $lines[0] =~ /^\S+.*:\s/) {
        while ($i < $total) {
            my $line = $lines[$i];

            # Blank line terminates title page
            if ($line =~ /^\s*$/) {
                $i += 1;
                # Skip additional blank lines after title page
                while ($i < $total && $lines[$i] =~ /^\s*$/) {
                    $i += 1;
                }
                last;
            }

            # Key: value
            if ($line =~ /^(\S[^:]*?):\s*(.*)$/) {
                my $key = lc $1;
                my $value = $2;
                $value =~ s/^\s+//;
                $value =~ s/\s+$//;
                $emit->('front_matter', $key, $value);
            }
            # Indented continuation (multi-line value) — skip
            # (we don't need multi-line values for our use case)

            $i += 1;
        }
    }

    # --- Body ---
    my $after_character = 0;
    my $prev_blank = 1;

    while ($i < $total) {
        my $line = $lines[$i];

        # Blank line
        if ($line =~ /^\s*$/) {
            $prev_blank = 1;
            $after_character = 0;
            $i += 1;
            next;
        }

        # Boneyard (comments): /* ... */
        if ($line =~ /^\/\*/) {
            while ($i < $total && $lines[$i] !~ /\*\//) {
                $i += 1;
            }
            $i += 1;  # skip closing line
            $prev_blank = 0;
            next;
        }

        # Synopsis: = text (dropped with warning)
        if ($line =~ /^=\s+(.+)$/ && $line !~ /^={3,}\s*$/) {
            $warn->($i + 1, "dropping synopsis (no event-stream equivalent)");
            $i += 1;
            $prev_blank = 0;
            next;
        }

        # Page break: === (dropped with warning)
        if ($line =~ /^={3,}\s*$/) {
            $warn->($i + 1, "dropping page break (no event-stream equivalent)");
            $i += 1;
            $prev_blank = 1;
            next;
        }

        # Note: [[text]] (inline or standalone)
        if ($line =~ /^\[\[(.+?)\]\]$/) {
            $emit->('footnote_def', "note_" . ($i + 1), $1);
            $i += 1;
            $prev_blank = 0;
            next;
        }

        # Section: # Title, ## Title, etc.
        if ($line =~ /^(#+)\s+(.+)$/) {
            my $level = length($1);
            my $title = $2;
            if ($level == 1) {
                $emit->('act_header', $title);
            } else {
                $emit->('scene_header', $title);
            }
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Forced scene heading: .Title
        if ($line =~ /^\.(\S.*)$/) {
            $emit->('scene_header', $1);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Scene heading: INT/EXT etc.
        if ($prev_blank && $line =~ /^(INT|EXT|EST|I\/E|INT\.\/EXT|INT\/EXT)[\.\s]/i) {
            $emit->('scene_header', $line);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Centred bold text: > **TITLE** < — used for act/intro headings in stage plays
        if ($line =~ /^>\s*\*\*(.+?)\*\*\s*<$/) {
            $emit->('act_header', $1);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Centred text: >TEXT<
        if ($line =~ /^>(.+)<$/) {
            $emit->('prop_text', $1);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Transition: UPPERCASE ending in TO:
        if ($prev_blank && $line =~ /^[A-Z\s]+TO:\s*$/) {
            $emit->('transition', $line);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Forced transition: >text (without <)
        if ($line =~ /^>(.+)$/ && $line !~ /<$/) {
            $emit->('transition', $1);
            $after_character = 0;
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Lyrics: ~text (dropped to dialogue, lyric marker lost)
        if ($line =~ /^~(.+)$/) {
            $emit->('dialogue', $1);
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Character: ALL CAPS, preceded by blank line, not followed by blank line
        # Also handles @forced and (extension) like (O.S.)
        if ($prev_blank) {
            my $char_line = $line;
            my $forced = 0;

            if ($char_line =~ /^@(.+)$/) {
                $char_line = $1;
                $forced = 1;
            }

            # Remove dual dialogue marker
            $char_line =~ s/\s*\^$//;

            # Check if this looks like a character line
            # Must be ALL CAPS (with possible extension in parens) and have content after
            if ($forced || ($char_line =~ /^[\p{Lu}\s]+(?:\(.*\))?\s*$/ && $char_line =~ /\p{L}/)) {
                # Check next line is not blank (otherwise it's action)
                my $next_blank = ($i + 1 >= $total) || ($lines[$i + 1] =~ /^\s*$/);

                if (!$next_blank || $forced) {
                    # Extract name and extension
                    my $name = $char_line;
                    my $extension;
                    if ($name =~ /^(.+?)\s*\((.+)\)\s*$/) {
                        $name = $1;
                        $extension = $2;
                    }
                    $name =~ s/\s+$//;

                    # Check for parenthetical on next line
                    my $direction = $extension;
                    if ($i + 1 < $total && $lines[$i + 1] =~ /^\((.+)\)$/) {
                        $direction = $1;
                        $i += 1;  # consume parenthetical line
                    }

                    $emit->('character', $name, $direction);
                    $after_character = 1;
                    $prev_blank = 0;
                    $i += 1;
                    next;
                }
            }
        }

        # Dialogue (text after character)
        if ($after_character) {
            # Mid-dialogue parenthetical
            if ($line =~ /^\((.+)\)$/) {
                $emit->('dialogue', "($1)");
            } else {
                $emit->('dialogue', $line);
            }
            $prev_blank = 0;
            $i += 1;
            next;
        }

        # Action (everything else = stage direction)
        # Forced action with !
        my $text = $line;
        $text =~ s/^!//;
        $emit->('stage_direction', $text);
        $after_character = 0;
        $prev_blank = 0;
        $i += 1;
    }

    $emit->('end');
}

1;
