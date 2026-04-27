# ABOUTME: Markdown play parser — recognises the conventions from Folio's Markdown emitter.
# ABOUTME: Parses headers, bold character names, italic stage directions, tables, and footnotes.
package Folio::Parser::Markdown;

use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

our $VERSION = '0.1.0';

sub parse {
    my ($class, $fh, $emitter) = @_;

    my $emit = sub {
        my ($event, @args) = @_;
        if (my $cb = $emitter->{$event}) {
            $cb->(@args);
        }
    };

    my $after_character   = 0;
    my $in_char_table     = 0;
    my $seen_title        = 0;
    my $expect_author     = 0;
    my $prev_blank        = 1;
    my $seen_any_character = 0;  # true once first character event emitted

    while (my $line = <$fh>) {
        chomp $line;

        # H1: title
        if ($line =~ /^# (.+)$/ && !$seen_title) {
            $emit->('front_matter', 'title', $1);
            $seen_title = 1;
            $expect_author = 1;
            $after_character = 0;
            $prev_blank = 0;
            next;
        }

        # Subtitle line: **Subtitle** (bold, after title)
        if ($expect_author && $line =~ /^\*\*(.+)\*\*$/) {
            $emit->('front_matter', 'subtitle', $1);
            $prev_blank = 0;
            next;
        }

        # Author line: *by Author*
        if ($expect_author && $line =~ /^\*by (.+)\*$/) {
            $emit->('front_matter', 'author', $1);
            $prev_blank = 0;
            next;
        }

        # Version/date line: --- version | date --- or --- version --- or --- date ---
        if ($expect_author && $line =~ /^---\s+(.+?)\s+---$/) {
            my $content = $1;
            if ($content =~ /^(.+?)\s*\|\s*(.+)$/) {
                $emit->('front_matter', 'version', $1);
                $emit->('front_matter', 'date', $2);
            } else {
                # Could be either — treat as version if not date-like
                $emit->('front_matter', 'version', $content);
            }
            $prev_blank = 0;
            next;
        }

        $expect_author = 0 if $line =~ /\S/;

        # H2: act header
        if ($line =~ /^## (.+)$/) {
            $after_character = 0;
            $emit->('act_header', $1);
            $prev_blank = 0;
            next;
        }

        # H3: scene header
        if ($line =~ /^### (.+)$/) {
            $after_character = 0;
            $emit->('scene_header', $1);
            $prev_blank = 0;
            next;
        }

        # Markdown table row — any table before first character dialogue is the character table
        if ($line =~ /^\|/) {
            # Separator row
            if ($line =~ /^\|[\s-]+\|/) {
                $prev_blank = 0;
                next;
            }

            # Parse table row
            my @cells = split(/\s*\|\s*/, $line);
            shift @cells if defined $cells[0] && $cells[0] eq '';

            if (@cells >= 2 && $cells[0] =~ /\S/) {
                # Before any dialogue: this is the character table
                if (!$seen_any_character) {
                    # Swallow header rows (Character, Name, Cast, etc.)
                    if (!$in_char_table) {
                        $in_char_table = 1;
                        $emit->('character_table_start');
                        # First row might be a header — skip if it looks like one
                        # (contains common header words, not ALL CAPS character names)
                        if ($cells[0] =~ /^(Character|Name|Cast|Role)s?$/i) {
                            $prev_blank = 0;
                            next;
                        }
                    }
                    $emit->('character_table_row', $cells[0], $cells[1] // '');
                }
                # Tables after first character are passed as dialogue (rare, but safe)
            }
            $prev_blank = 0;
            next;
        }

        # End character table on non-table line
        if ($in_char_table && $line !~ /^\|/) {
            $emit->('character_table_end');
            $in_char_table = 0;
        }

        # Blank line
        if ($line =~ /^\s*$/) {
            $prev_blank = 1;
            next;
        }

        # Transition: > TEXT (blockquote)
        if ($line =~ /^>\s+(.+)$/) {
            $emit->('transition', $1);
            $after_character = 0;
            $prev_blank = 0;
            next;
        }

        # Footnote definition: [^name]: text
        if ($line =~ /^\[\^(\S+)\]:\s+(.+)$/) {
            $emit->('footnote_def', $1, $2);
            $after_character = 0;
            $prev_blank = 0;
            next;
        }

        # Prop text: ***"TEXT"***
        if ($line =~ /^\*\*\*"(.+?)"\*\*\*$/) {
            $emit->('prop_text', $1);
            $after_character = 0;
            $prev_blank = 0;
            next;
        }

        # Character line: **NAME:** or **NAME:** *(direction)*
        if ($line =~ /^\*\*([^*]+?):\*\*\s*(?:\*\(([^)]+)\)\*)?$/) {
            my $name = $1;
            my $direction = $2;
            $emit->('character', $name, $direction);
            $after_character = 1;
            $seen_any_character = 1;
            $prev_blank = 0;
            next;
        }

        # Stage direction: standalone *italic text*
        # Must be a complete line wrapped in single asterisks, not bold
        if ($line =~ /^\*([^*].+[^*])\*$/ && !$after_character) {
            my $text = $1;
            # Convert Markdown markup back: **bold** -> *bold*, *italic* already stripped
            $text =~ s/\*\*([^*]+?)\*\*/*$1*/g;
            $emit->('stage_direction', $text);
            $after_character = 0;
            $prev_blank = 0;
            next;
        }

        # Dialogue or plain text
        if ($line =~ /\S/) {
            $emit->('dialogue', $line);
            $prev_blank = 0;
        }
    }

    if ($in_char_table) {
        $emit->('character_table_end');
    }
    $emit->('end');
}

1;
