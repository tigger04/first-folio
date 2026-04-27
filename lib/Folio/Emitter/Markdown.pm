# ABOUTME: Markdown emitter — converts event stream to idiomatic Markdown play format.
# ABOUTME: Uses ## for acts, ### for scenes, *italic* for directions, **bold** for characters.
package Folio::Emitter::Markdown;

use strict;
use warnings;
use utf8;

our $VERSION = '0.1.0';

# Create a new emitter. Returns a hashref of event callbacks.
# After parsing, call finish() on the returned object to get the output string.
sub new {
    my ($class) = @_;

    my %front_matter;
    my @md_lines;
    my $needs_blank = 0;
    my @char_table_rows;
    my %footnotes;

    my $emit_blank = sub {
        if ($needs_blank) {
            push @md_lines, '';
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
            push @md_lines, "## $title";
            $needs_blank = 1;
        },
        scene_header => sub {
            my ($title) = @_;
            $emit_blank->();
            push @md_lines, "### $title";
            $needs_blank = 1;
        },
        stage_direction => sub {
            my ($text) = @_;
            $emit_blank->();
            push @md_lines, "*${text}*";
            $needs_blank = 1;
        },
        character => sub {
            my ($name, $direction) = @_;
            $emit_blank->();
            if (defined $direction) {
                push @md_lines, "**${name}:** *(${direction})*";
            } else {
                push @md_lines, "**${name}:**";
            }
            $needs_blank = 0;
        },
        dialogue => sub {
            my ($line) = @_;
            push @md_lines, $line;
            $needs_blank = 1;
        },
        character_table_start => sub {
            my ($heading) = @_;
            # Heading not rendered in Markdown — the table header row serves this purpose
            @char_table_rows = ();
        },
        character_table_row => sub {
            my ($name, $desc) = @_;
            push @char_table_rows, [$name, $desc];
        },
        character_table_end => sub {
            if (@char_table_rows) {
                $emit_blank->();
                my $max_name = 9;  # "Character"
                my $max_desc = 11; # "Description"
                for my $row (@char_table_rows) {
                    my $nlen = length($row->[0]);
                    my $dlen = length($row->[1]);
                    $max_name = $nlen if $nlen > $max_name;
                    $max_desc = $dlen if $dlen > $max_desc;
                }
                push @md_lines, sprintf("| %-${max_name}s | %-${max_desc}s |", 'Character', 'Description');
                push @md_lines, sprintf("|-%s-|-%s-|", '-' x $max_name, '-' x $max_desc);
                for my $row (@char_table_rows) {
                    push @md_lines, sprintf("| %-${max_name}s | %-${max_desc}s |", $row->[0], $row->[1]);
                }
                $needs_blank = 1;
            }
        },
        prop_text => sub {
            my ($text) = @_;
            $emit_blank->();
            push @md_lines, "***\"${text}\"***";
            $needs_blank = 1;
        },
        footnote_def => sub {
            my ($name, $text) = @_;
            $footnotes{$name} = $text;
        },
        transition => sub {
            my ($text) = @_;
            $emit_blank->();
            push @md_lines, "> $text";
            $needs_blank = 1;
        },
        intro_header => sub {
            my ($title) = @_;
            $emit_blank->();
            push @md_lines, "## $title";
            $needs_blank = 1;
        },
        intro_text => sub {
            my ($line) = @_;
            push @md_lines, $line;
            $needs_blank = 1;
        },
        end => sub {
            # nothing
        },
    };

    my $self = bless {
        emitter      => $emitter,
        front_matter => \%front_matter,
        md_lines     => \@md_lines,
        footnotes    => \%footnotes,
    }, $class;

    return $self;
}

sub emitter { return $_[0]->{emitter} }

# Build final output string after parsing is complete.
sub finish {
    my ($self, %overrides) = @_;

    my %fm = %{$self->{front_matter}};
    # Apply config overrides
    for my $key (keys %overrides) {
        $fm{$key} = $overrides{$key} if defined $overrides{$key};
    }

    my @output;

    if (my $title = $fm{title}) {
        push @output, "# $title";
        if (my $subtitle = $fm{subtitle}) {
            push @output, '';
            push @output, "**${subtitle}**";
        }
        if (my $author = $fm{author}) {
            push @output, '';
            push @output, "*by ${author}*";
        }
        my @meta_line;
        if (my $version = $fm{version}) { push @meta_line, $version }
        if (my $date = $fm{date}) { push @meta_line, $date }
        if (@meta_line) {
            push @output, '';
            push @output, '--- ' . join(' | ', @meta_line) . ' ---';
        }
        push @output, '';
    }

    push @output, @{$self->{md_lines}};

    my %fn = %{$self->{footnotes}};
    if (%fn) {
        # Convert inline references
        for my $i (0 .. $#output) {
            $output[$i] =~ s/\[fn:(\S+?)\]/
                exists $fn{$1} ? "[^$1]" : "[fn:$1]"
            /ge;
        }
        push @output, '';
        for my $name (sort keys %fn) {
            push @output, "[^$name]: $fn{$name}";
        }
    }

    return join("\n", @output) . "\n";
}

1;
