# ABOUTME: Fountain emitter — converts event stream to Fountain screenplay/stage play format.
# ABOUTME: Uses centred bold text for act headings, forced headings for scenes, ALL-CAPS for characters.
package Folio::Emitter::Fountain;

use strict;
use warnings;
use utf8;

our $VERSION = '0.1.0';

sub new {
    my ($class, %opts) = @_;

    my $warn_fh = $opts{warn_fh} || \*STDERR;

    my %front_matter;
    my @lines;
    my @char_table_rows;
    my $char_table_heading;
    my %footnotes;
    my $needs_blank = 0;

    my $emit_blank = sub {
        if ($needs_blank) {
            push @lines, '';
            $needs_blank = 0;
        }
    };

    my $emitter = {
        front_matter => sub {
            my ($key, $value) = @_;
            $front_matter{$key} = $value;
        },
        act_header => sub {
            my ($title) = @_;
            $emit_blank->();
            # Page break before each act
            push @lines, '===';
            push @lines, '';
            # Centred bold uppercase for visibility in formatted output
            push @lines, "> **\U$title** <";
            push @lines, '';
            $needs_blank = 0;
        },
        scene_header => sub {
            my ($title) = @_;
            $emit_blank->();
            # Use forced scene heading (.) unless it already starts with INT/EXT
            my $upper = uc($title);
            if ($title =~ /^(INT|EXT|EST|I\/E)/i) {
                push @lines, $upper;
            } else {
                push @lines, ".$upper";
            }
            $needs_blank = 1;
        },
        stage_direction => sub {
            my ($text) = @_;
            $emit_blank->();
            push @lines, $text;
            $needs_blank = 1;
        },
        character => sub {
            my ($name, $direction) = @_;
            $emit_blank->();
            push @lines, uc($name);
            if (defined $direction) {
                push @lines, "($direction)";
            }
            $needs_blank = 0;
        },
        dialogue => sub {
            my ($line) = @_;
            push @lines, $line;
            $needs_blank = 1;
        },
        character_table_start => sub {
            my ($heading) = @_;
            $char_table_heading = $heading // 'Characters';
            @char_table_rows = ();
        },
        character_table_row => sub {
            my ($name, $desc) = @_;
            push @char_table_rows, [$name, $desc];
        },
        character_table_end => sub {
            if (@char_table_rows) {
                print $warn_fh "warning: character table has no Fountain equivalent, rendering as Action text\n";
                $emit_blank->();
                # Centred heading for the cast list
                push @lines, "> **\U$char_table_heading** <";
                push @lines, '';
                # Plain action text with blank lines between entries
                for my $i (0 .. $#char_table_rows) {
                    push @lines, '' if $i > 0;
                    push @lines, "$char_table_rows[$i][0] - $char_table_rows[$i][1]";
                }
                $needs_blank = 1;
            }
        },
        prop_text => sub {
            my ($text) = @_;
            $emit_blank->();
            push @lines, ">$text<";
            $needs_blank = 1;
        },
        footnote_def => sub {
            my ($name, $text) = @_;
            $footnotes{$name} = $text;
        },
        transition => sub {
            my ($text) = @_;
            $emit_blank->();
            # Uppercase transitions per Fountain convention
            push @lines, uc($text);
            $needs_blank = 1;
        },
        intro_header => sub {
            my ($title) = @_;
            $emit_blank->();
            # Centred bold uppercase for visibility
            push @lines, "> **\U$title** <";
            push @lines, '';
            $needs_blank = 0;
        },
        intro_text => sub {
            my ($line) = @_;
            # Strip list-item bullets — Fountain has no list syntax
            $line =~ s/^-\s+//;
            push @lines, $line;
            $needs_blank = 1;
        },
        end => sub {
            # nothing
        },
    };

    return bless {
        emitter      => $emitter,
        front_matter => \%front_matter,
        lines        => \@lines,
        footnotes    => \%footnotes,
    }, $class;
}

sub emitter { return $_[0]->{emitter} }

sub finish {
    my ($self, %overrides) = @_;

    my %fm = %{$self->{front_matter}};
    for my $key (keys %overrides) {
        $fm{$key} = $overrides{$key} if defined $overrides{$key};
    }

    my @output;

    # Title page — Fountain spec keys only
    # Subtitle is not a Fountain key; fold into Title as indented continuation
    my $has_title_page = 0;

    if (defined $fm{title} && $fm{title} ne '') {
        my $title_block = "Title: $fm{title}";
        if (defined $fm{subtitle} && $fm{subtitle} ne '') {
            $title_block .= "\n    $fm{subtitle}";
        }
        push @output, $title_block;
        $has_title_page = 1;
    }

    if (defined $fm{author} && $fm{author} ne '') {
        push @output, "Author: $fm{author}";
        $has_title_page = 1;
    }

    if (defined $fm{version} && $fm{version} ne '') {
        push @output, "Draft date: $fm{version}";
        $has_title_page = 1;
    }

    if (defined $fm{date} && $fm{date} ne '') {
        push @output, "Date: $fm{date}";
        $has_title_page = 1;
    }

    if ($has_title_page) {
        push @output, '';  # blank line terminates title page
    }

    push @output, @{$self->{lines}};

    # Footnotes as notes
    my %fn = %{$self->{footnotes}};
    if (%fn) {
        push @output, '';
        for my $name (sort keys %fn) {
            push @output, "[[$fn{$name}]]";
        }
    }

    return join("\n", @output) . "\n";
}

1;
