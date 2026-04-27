# ABOUTME: Org-mode play parser — line-by-line state machine emitting typed events.
# ABOUTME: Handles Unicode character names, direction normalisation, and :noexport: sections.
package Folio::Parser::Org;

use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

our $VERSION = '0.1.0';

# Parse an org-mode play from a filehandle, calling back into an emitter.
#
# The emitter is a hashref of callbacks keyed by event name:
#   front_matter => sub { my ($key, $value) = @_; ... }
#   act_header   => sub { my ($title) = @_; ... }
#   scene_header => sub { my ($title) = @_; ... }
#   stage_direction => sub { my ($text) = @_; ... }
#   character    => sub { my ($name, $direction_or_undef) = @_; ... }
#   dialogue     => sub { my ($line) = @_; ... }
#   character_table_row => sub { my ($name, $description) = @_; ... }
#   character_table_start => sub { ... }
#   character_table_end   => sub { ... }
#   prop_text    => sub { my ($text) = @_; ... }
#   end          => sub { ... }
#
# Missing callbacks are silently skipped.
sub parse {
    my ($class, $fh, $emitter) = @_;

    my $in_noexport   = 0;
    my $noexport_level = 0;
    my $in_char_table = 0;
    my $after_h4      = 0;  # true if previous line was an H4

    my $emit = sub {
        my ($event, @args) = @_;
        if (my $cb = $emitter->{$event}) {
            $cb->(@args);
        }
    };

    while (my $line = <$fh>) {
        chomp $line;

        # --- Front matter: #+KEY: value ---
        if ($line =~ /^#\+(\w+):\s*(.*)$/) {
            my ($key, $value) = (lc($1), $2);
            # #+DATE and #+VERSION are standard org keywords
            $emit->('front_matter', $key, $value);
            $after_h4 = 0;
            next;
        }

        # --- Heading lines ---
        if ($line =~ /^(\*+)\s+(.*)$/) {
            my $level = length($1);
            my $text  = $2;

            # End character table if we were in one
            if ($in_char_table) {
                $emit->('character_table_end');
                $in_char_table = 0;
            }

            # Check for :noexport: tag
            if ($text =~ /:noexport:/) {
                $in_noexport = 1;
                $noexport_level = $level;
                $after_h4 = 0;
                next;
            }

            # If we're in a noexport section, check if this heading exits it
            if ($in_noexport) {
                if ($level <= $noexport_level) {
                    $in_noexport = 0;
                    # Fall through to process this heading normally
                } else {
                    next;
                }
            }

            if ($level == 1) {
                # Check if this is the CHARACTERS section
                if ($text =~ /^\s*CHARACTERS?\s*$/i) {
                    $in_char_table = 1;
                    $emit->('character_table_start');
                } else {
                    $emit->('act_header', $text);
                }
                $after_h4 = 0;
            } elsif ($level == 2) {
                $emit->('scene_header', $text);
                $after_h4 = 0;
            } elsif ($level == 3) {
                $emit->('stage_direction', $text);
                $after_h4 = 0;
            } elsif ($level == 4) {
                my ($name, $direction) = _parse_character_line($text);
                $emit->('character', $name, $direction);
                $after_h4 = 1;
            } elsif ($level == 5) {
                $emit->('transition', $text);
                $after_h4 = 0;
            }
            next;
        }

        # Skip if in noexport
        if ($in_noexport) {
            next;
        }

        # --- Org table rows (character table) ---
        if ($in_char_table && $line =~ /^\s*\|/) {
            # Skip separator rows
            if ($line =~ /^\s*\|[-+]+\|/) {
                next;
            }
            # Parse table row: | NAME | Description |
            my @cells = split(/\s*\|\s*/, $line);
            # split produces empty first element due to leading |
            shift @cells if defined $cells[0] && $cells[0] eq '';
            if (@cells >= 2 && $cells[0] =~ /\S/) {
                $emit->('character_table_row', $cells[0], $cells[1] // '');
            }
            $after_h4 = 0;
            next;
        }

        # End character table on non-table line
        if ($in_char_table && $line !~ /^\s*\|/ && $line =~ /\S/) {
            $emit->('character_table_end');
            $in_char_table = 0;
        }

        # --- Footnote definition: [fn:name] text ---
        if ($line =~ /^\[fn:(\S+)\]\s+(.+)$/) {
            $emit->('footnote_def', $1, $2);
            $after_h4 = 0;
            next;
        }

        # --- Prop text: - *"TEXT"* ---
        if ($line =~ /^\s*-\s+\*"(.+?)"\*\s*$/) {
            $emit->('prop_text', $1);
            $after_h4 = 0;
            next;
        }

        # --- Dialogue (plain text, possibly after an H4) ---
        if ($line =~ /\S/) {
            $emit->('dialogue', $line);
            # Keep after_h4 false after first dialogue line
            $after_h4 = 0;
        }
        # Blank lines are silently consumed
    }

    # Clean up
    if ($in_char_table) {
        $emit->('character_table_end');
    }
    $emit->('end');
}

# Parse a character line (text after ****) into (name, direction_or_undef).
# Handles all variants:
#   BOB softly       -> (BOB, softly)
#   BOB (softly)     -> (BOB, softly)
#   BOB, softly      -> (BOB, softly)
#   BOB, (softly)    -> (BOB, softly)
#   BOB              -> (BOB, undef)
sub _parse_character_line {
    my ($text) = @_;

    # Match uppercase character name (2+ uppercase Unicode letters, possibly with punctuation after)
    # Then optional direction
    if ($text =~ /^(\p{Lu}[\p{Lu}\s]*\p{Lu}|\p{Lu}+)\s*[,:]?\s*(.*)$/) {
        my $name = $1;
        my $rest = $2;

        # Clean up name: trim trailing whitespace
        $name =~ s/\s+$//;

        # Normalise direction
        my $direction;
        if (defined $rest && $rest =~ /\S/) {
            $direction = $rest;
            # Strip outer parentheses
            $direction =~ s/^\(\s*//;
            $direction =~ s/\s*\)$//;
            # Strip leading comma/colon and whitespace (in case regex didn't catch it)
            $direction =~ s/^[,:\s]+//;
            # Trim
            $direction =~ s/^\s+//;
            $direction =~ s/\s+$//;
            $direction = undef if $direction eq '';
        }

        return ($name, $direction);
    }

    # Fallback: entire text is the name
    return ($text, undef);
}

1;
