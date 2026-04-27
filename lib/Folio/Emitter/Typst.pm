# ABOUTME: Typst/PDF emitter — converts event stream to Typst source, optionally compiles to PDF.
# ABOUTME: Uses OrgPlay::TypstTemplate for preamble and title page layout.
package Folio::Emitter::Typst;

use strict;
use warnings;
use utf8;

use File::Temp qw(tempfile);
use OrgPlay::TypstTemplate;

our $VERSION = '0.1.0';

sub new {
    my ($class, %opts) = @_;

    my %front_matter;
    my @typst_body;
    my $in_dialogue = 0;
    my %footnotes;
    my @char_table_rows;
    my $char_table_heading = 'Characters';
    my %known_characters;  # names from char table + character events

    my $emitter = {
        front_matter => sub {
            my ($key, $value) = @_;
            $front_matter{$key} = $value;
        },
        transition => sub {
            my ($text) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            my $escaped = _escape_typst($text);
            push @typst_body, "#align(right)[#text(style: \"normal\")[${escaped}]]";
        },
        intro_header => sub {
            my ($title) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            push @typst_body, "#text(size: 1.2em, weight: \"bold\")[${title}]";
            push @typst_body, '';
        },
        intro_text => sub {
            my ($line) = @_;
            my $escaped = _escape_typst($line);
            push @typst_body, "${escaped}";
            push @typst_body, '';
        },
        act_header => sub {
            my ($title) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            push @typst_body, '#pagebreak()';
            push @typst_body, "#act-header[${title}]";
        },
        scene_header => sub {
            my ($title) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            push @typst_body, "#scene-header[${title}]";
        },
        stage_direction => sub {
            my ($text) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            # Uppercase character names in stage directions (actor cue convention)
            $text = _uppercase_character_names($text, \%known_characters);
            my $escaped = _escape_typst($text);
            push @typst_body, "#stage-direction[${escaped}]";
        },
        character => sub {
            my ($name, $direction) = @_;
            $known_characters{$name} = 1;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            $in_dialogue = 1;
            my $dir_arg = '';
            if (defined $direction) {
                my $escaped_dir = _escape_typst($direction);
                $dir_arg = ", direction: \"${escaped_dir}\"";
            }
            push @typst_body, "#dialogue(\"${name}\"${dir_arg})[";
        },
        dialogue => sub {
            my ($line) = @_;
            my $escaped = _escape_typst($line);
            if ($in_dialogue) {
                push @typst_body, "${escaped} \\";
            } else {
                push @typst_body, "${escaped}\n";
            }
        },
        character_table_start => sub {
            my ($heading) = @_;
            $char_table_heading = $heading // 'Characters';
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            @char_table_rows = ();
        },
        character_table_row => sub {
            my ($name, $desc) = @_;
            push @char_table_rows, [$name, $desc];
            $known_characters{$name} = 1;
        },
        character_table_end => sub {
            if (@char_table_rows) {
                my $esc_heading = _escape_typst($char_table_heading);
                push @typst_body, "#text(size: 1.2em, weight: \"bold\")[${esc_heading}]";
                push @typst_body, '#v(0.5em)';
                push @typst_body, '#align(center)[#block(width: 85%)[';
                push @typst_body, '#table(';
                push @typst_body, '  columns: (30%, 1fr),';
                push @typst_body, '  align: (left, left),';
                push @typst_body, '  stroke: none,';
                for my $row (@char_table_rows) {
                    my $esc_name = _escape_typst(uc($row->[0]));
                    my $esc_desc = _escape_typst($row->[1]);
                    push @typst_body, "  [*${esc_name}*], [${esc_desc}],";
                }
                push @typst_body, ')';
                push @typst_body, ']]';
            }
        },
        prop_text => sub {
            my ($text) = @_;
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
            my $escaped = _escape_typst($text);
            push @typst_body, "#prop-text[${escaped}]";
        },
        footnote_def => sub {
            my ($name, $text) = @_;
            $footnotes{$name} = $text;
        },
        end => sub {
            if ($in_dialogue) { push @typst_body, ']'; $in_dialogue = 0; }
        },
    };

    return bless {
        emitter      => $emitter,
        front_matter => \%front_matter,
        typst_body   => \@typst_body,
        footnotes    => \%footnotes,
        config       => $opts{config},
    }, $class;
}

sub emitter { return $_[0]->{emitter} }

# Build the Typst source and optionally compile to PDF.
# Returns the output path.
sub finish {
    my ($self, %opts) = @_;

    my $output     = $opts{output}     // 'output.pdf';
    my $config     = $opts{config}     // $self->{config};
    my %overrides  = %{$opts{overrides} // {}};

    my %fm = %{$self->{front_matter}};
    for my $key (keys %overrides) {
        $fm{$key} = $overrides{$key} if defined $overrides{$key};
    }

    # Post-process footnotes
    my %fn = %{$self->{footnotes}};
    my @body = @{$self->{typst_body}};
    if (%fn) {
        for my $i (0 .. $#body) {
            $body[$i] =~ s/\[fn:(\S+?)\]/
                exists $fn{$1}
                    ? '#footnote[' . _escape_typst($fn{$1}) . ']'
                    : "[fn:$1]"
            /ge;
        }
    }

    my $preamble = OrgPlay::TypstTemplate->preamble(config => $config);

    my $title_page = OrgPlay::TypstTemplate->title_page(
        config   => $config,
        title    => $fm{title}        // '',
        subtitle => $fm{subtitle}     // '',
        author   => $fm{author}       // '',
        date     => $fm{date}         // '',
        version  => $fm{version}      // '',
    );

    my $typst_doc = $preamble . $title_page . join("\n", @body) . "\n";

    # If output ends in .typ, write Typst source only
    if ($output =~ /\.typ$/) {
        open(my $out_fh, '>:encoding(UTF-8)', $output)
            or die "Error: cannot write to $output: $!\n";
        print $out_fh $typst_doc;
        close $out_fh;
        return $output;
    }

    # Write to temp .typ, compile to PDF
    my ($tmp_fh, $tmp_path) = tempfile('folio-XXXX', SUFFIX => '.typ', TMPDIR => 1);
    binmode($tmp_fh, ':encoding(UTF-8)');
    print $tmp_fh $typst_doc;
    close $tmp_fh;

    my @cmd = ('typst', 'compile', $tmp_path, $output);
    system(@cmd) == 0
        or die "Error: typst compile failed (exit $?)\n";

    unlink $tmp_path;
    return $output;
}

# Write PDF to stdout (for --force / piped output)
sub finish_to_stdout {
    my ($self, %opts) = @_;

    my $config    = $opts{config}    // $self->{config};
    my %overrides = %{$opts{overrides} // {}};

    # Compile to temp PDF, then cat to stdout
    my ($tmp_fh, $tmp_path) = tempfile('folio-XXXX', SUFFIX => '.pdf', TMPDIR => 1);
    close $tmp_fh;

    $self->finish(output => $tmp_path, config => $config, overrides => \%overrides);

    open(my $pdf_fh, '<:raw', $tmp_path)
        or die "Error: cannot read compiled PDF: $!\n";
    binmode(STDOUT);
    while (read($pdf_fh, my $buf, 8192)) {
        print STDOUT $buf;
    }
    close $pdf_fh;
    unlink $tmp_path;
}

# Uppercase known character names in stage direction text using word boundaries.
sub _uppercase_character_names {
    my ($text, $characters) = @_;
    for my $name (keys %$characters) {
        $text =~ s/\b\Q$name\E\b/uc($name)/ge;
    }
    return $text;
}

sub _escape_typst {
    my ($text) = @_;

    my @markup_slots;
    # Process multi-char markers first, then single-char
    # Markdown/Fountain bold italic: ***text*** -> Typst *_text_*
    $text =~ s{\*\*\*([^*\n]+?)\*\*\*}{
        push @markup_slots, "*_${1}_*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Markdown/Fountain bold: **text** -> Typst *text*
    $text =~ s{\*\*([^*\n]+?)\*\*}{
        push @markup_slots, "*${1}*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org underline: _text_ -> Typst #underline[text]
    # Process after ** so _**text**_ captures the bold placeholder inside
    $text =~ s{(?<!\w)_([^_\n]+?)_(?!\w)}{
        my $inner = $1;
        # Restore any markup placeholders inside the underline content
        $inner =~ s/\x00MARKUP(\d+)\x00/$markup_slots[$1]/g;
        push @markup_slots, "#underline[${inner}]";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org italic: /text/ -> Typst _text_
    $text =~ s{(?<!\w)/([^/\n]+?)/(?!\w)}{
        push @markup_slots, "_${1}_";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org bold: *text* -> Typst *text*
    $text =~ s{(?<!\w)\*([^*\n]+?)\*(?!\w)}{
        push @markup_slots, "*${1}*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;

    $text =~ s/\\/\\\\/g;
    $text =~ s/_/\\_/g;
    $text =~ s/\*/\\*/g;
    $text =~ s/\$/\\\$/g;
    $text =~ s/@/\\@/g;
    $text =~ s/(?<!^)#/\\#/g if $text !~ /^#/;

    $text =~ s/\x00MARKUP(\d+)\x00/$markup_slots[$1]/g;

    return $text;
}

1;
