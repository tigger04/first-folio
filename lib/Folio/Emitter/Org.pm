# ABOUTME: Org-mode emitter — converts event stream to structured org-mode play format.
# ABOUTME: Uses heading levels: * acts, ** scenes, *** directions, **** characters.
package Folio::Emitter::Org;

use strict;
use warnings;
use utf8;

our $VERSION = '0.1.0';

sub new {
    my ($class) = @_;

    my %front_matter;
    my @lines;
    my @char_table_rows;
    my $char_table_heading = 'CHARACTERS';
    my %footnotes;

    my $emitter = {
        front_matter => sub {
            my ($key, $value) = @_;
            $front_matter{$key} = $value;
        },
        act_header => sub {
            my ($title) = @_;
            push @lines, '';
            push @lines, "* $title";
        },
        scene_header => sub {
            my ($title) = @_;
            push @lines, "** $title";
        },
        stage_direction => sub {
            my ($text) = @_;
            push @lines, "*** $text";
        },
        character => sub {
            my ($name, $direction) = @_;
            if (defined $direction) {
                push @lines, "**** $name $direction";
            } else {
                push @lines, "**** $name";
            }
        },
        dialogue => sub {
            my ($line) = @_;
            push @lines, $line;
        },
        character_table_start => sub {
            my ($heading) = @_;
            $char_table_heading = $heading // 'CHARACTERS';
            @char_table_rows = ();
        },
        character_table_row => sub {
            my ($name, $desc) = @_;
            push @char_table_rows, [$name, $desc];
        },
        character_table_end => sub {
            if (@char_table_rows) {
                push @lines, '';
                push @lines, "* $char_table_heading";
                # Build org table
                my $max_name = 0;
                my $max_desc = 0;
                for my $row (@char_table_rows) {
                    my $nlen = length($row->[0]);
                    my $dlen = length($row->[1]);
                    $max_name = $nlen if $nlen > $max_name;
                    $max_desc = $dlen if $dlen > $max_desc;
                }
                my $sep = sprintf("|-%s-+-%s-|", '-' x $max_name, '-' x $max_desc);
                push @lines, $sep;
                for my $row (@char_table_rows) {
                    push @lines, sprintf("| %-${max_name}s | %-${max_desc}s |", $row->[0], $row->[1]);
                }
                push @lines, $sep;
            }
        },
        prop_text => sub {
            my ($text) = @_;
            push @lines, "- *\"${text}\"*";
        },
        footnote_def => sub {
            my ($name, $text) = @_;
            $footnotes{$name} = $text;
        },
        transition => sub {
            my ($text) = @_;
            push @lines, "***** $text";
        },
        intro_header => sub {
            my ($title) = @_;
            push @lines, '';
            push @lines, "* $title";
        },
        intro_text => sub {
            my ($line) = @_;
            push @lines, $line;
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

    # Front matter as #+KEY: value
    for my $key (qw(title subtitle author date version)) {
        if (defined $fm{$key} && $fm{$key} ne '') {
            push @output, '#+' . uc($key) . ': ' . $fm{$key};
        }
    }

    push @output, @{$self->{lines}};

    # Footnotes
    my %fn = %{$self->{footnotes}};
    if (%fn) {
        push @output, '';
        for my $name (sort keys %fn) {
            push @output, "[fn:$name] $fn{$name}";
        }
    }

    return join("\n", @output) . "\n";
}

1;
