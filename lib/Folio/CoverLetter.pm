# ABOUTME: Cover letter parser and generator from org :letter: tagged sections.
# ABOUTME: Extracts structured letter data and renders via Typst.
package Folio::CoverLetter;

use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

use File::Temp qw(tempfile);
use File::Basename qw(dirname);

our $VERSION = '0.1.0';

my @MONTHS = qw(January February March April May June July August September October November December);

# Parse an org file and extract cover letter data.
# Returns an arrayref of letter hashes, one per recipient.
sub parse {
    my ($class, $fh, %opts) = @_;

    my %front_matter;
    my @letters;
    my $in_cover = 0;

    # Letter-level state
    my $sender;
    my $current_subject;
    my $current_body = '';
    my $current_closing;
    my $current_signoff;
    my @current_recipients;
    my $current_date;

    my $flush = sub {
        return unless $current_subject && @current_recipients;

        my $body = $current_body;
        $body =~ s/^\s+//;
        $body =~ s/\s+$//;

        my $closing = $current_closing // 'Yours sincerely';
        my $signoff = $current_signoff // $front_matter{author} // '';

        for my $recip (@current_recipients) {
            my $letter_body = $body;

            # Placeholder substitution — merge all sources into one lookup
            my %vars = (
                %front_matter,            # #+TITLE, #+AUTHOR, etc.
                %$recip,                  # org, moniker, address, any custom tags
            );
            $letter_body =~ s/\[(\w+)\]/defined $vars{$1} ? $vars{$1} : "[$1]"/ge;

            push @letters, {
                sender    => $sender // $front_matter{author} // '',
                subject   => $current_subject,
                body      => $letter_body,
                closing   => $closing,
                signoff   => $signoff,
                recipient => $recip->{address},
                org       => $recip->{org}     // '',
                moniker   => $recip->{moniker} // '',
                date      => $current_date,
                author    => $front_matter{author} // '',
                email     => $front_matter{email}  // '',
                contact   => $front_matter{contact} // '',
            };
        }

        # Reset for next letter
        $current_subject = undef;
        $current_body = '';
        $current_closing = undef;
        $current_signoff = undef;
        @current_recipients = ();
        $current_date = undef;
    };

    while (my $line = <$fh>) {
        chomp $line;

        # Front matter: #+KEY: value
        if ($line =~ /^#\+(\w+):\s*(.*)$/) {
            $front_matter{lc($1)} = $2;
            next;
        }

        # H1 with :letter: tag — enter cover letter mode
        if ($line =~ /^\*\s+.*:letter:\s*$/) {
            $in_cover = 1;
            next;
        }

        # Any H1 without :letter: — exit cover letter mode
        if ($line =~ /^\*\s+/ && $line !~ /:letter:/) {
            $flush->();
            $in_cover = 0;
            next;
        }

        next unless $in_cover;

        # H2 :sender:
        if ($line =~ /^\*\*\s+(.*?)\s*:sender:\s*$/) {
            $sender = $1;
            next;
        }

        # H2 :subject: — new letter (flush previous)
        if ($line =~ /^\*\*\s+(.*?)\s*:subject:\s*$/) {
            $flush->();
            $current_subject = $1;
            next;
        }

        # H3 :closing:
        if ($line =~ /^\*{3}\s+(.*?)\s*:closing:\s*$/) {
            $current_closing = $1;
            next;
        }

        # H3 :signoff: — printed name (may differ from #+AUTHOR)
        if ($line =~ /^\*{3}\s+(.*?)\s*:signoff:\s*$/) {
            $current_signoff = $1;
            next;
        }

        # H3 :to: — recipient
        if ($line =~ /^\*{3}\s+(.*?)\s*:to:\s*$/) {
            push @current_recipients, { address => $1 };
            next;
        }

        # H4 with any tag — captured as recipient-level variable
        if ($line =~ /^\*{4}\s+(.*?)\s*:(\w+):\s*$/) {
            if (@current_recipients) {
                $current_recipients[-1]{$2} = $1;
            }
            next;
        }

        # Org timestamp — letter date (active or passive)
        if ($line =~ /^\*{3}\s+[\[<](\d{4}-\d{2}-\d{2})/) {
            $current_date = $1;
            next;
        }

        # Skip unrecognised headings within cover
        next if $line =~ /^\*{2,}\s+/;

        # Body text
        if (defined $current_subject) {
            $current_body .= "$line\n";
        }
    }

    # Flush final letter
    $flush->();

    return \@letters;
}

# Render a single letter to PDF via Typst.
sub render_pdf {
    my ($class, $letter, %opts) = @_;

    my $output = $opts{output} // 'letter.pdf';
    my $config = $opts{config};

    my $g = sub { $config ? ($config->get("folio.letter.$_[0]") // $_[1]) : $_[1] };

    my $font         = $g->('font', 'Libertinus Serif');
    my $font_size    = $g->('font-size', '11pt');
    my $page         = $g->('page', 'a4');
    my $m_top        = $g->('margin-top', '25mm');
    my $m_bot        = $g->('margin-bottom', '25mm');
    my $m_left       = $g->('margin-left', '30mm');
    my $m_right      = $g->('margin-right', '25mm');
    my $sp_closing   = $g->('space-before-closing', '1.2em');
    my $sp_signoff   = $g->('space-before-signoff', '1.5em');
    my $sp_sender    = $g->('space-after-sender', '2em');
    my $sp_recip     = $g->('space-after-recipient', '1em');
    my $sp_date      = $g->('space-after-date', '1em');
    my $sp_subject   = $g->('space-after-subject', '0.5em');

    # Format date — expand ISO to long form, or use as-is if unparseable
    my $date = _format_date($letter->{date});

    # Split slash-separated addresses into lines
    my $sender_lines = _format_address($letter->{sender});
    my $recip_lines  = _format_address($letter->{recipient});

    # Contact info below sender
    my $contact_block = '';
    if ($letter->{email}) {
        $contact_block .= _escape_typst($letter->{email}) . "\\\n";
    }
    if ($letter->{contact}) {
        $contact_block .= _escape_typst($letter->{contact}) . "\\\n";
    }

    # Build body paragraphs
    my @paragraphs = split /\n\n+/, $letter->{body};
    my $body_typst = join("\n\n", map { _escape_typst($_) } @paragraphs);

    my $subject_escaped = _escape_typst($letter->{subject});
    my $closing_escaped = _escape_typst($letter->{closing});
    my $signoff_escaped = _escape_typst($letter->{signoff});

    my $typst = <<"TYPST";
#set page(paper: "${page}", margin: (top: ${m_top}, bottom: ${m_bot}, left: ${m_left}, right: ${m_right}))
#set text(font: "${font}", size: ${font_size})
#set par(leading: 0.8em, spacing: 1.2em)

// Sender — top right
#align(right)[
${sender_lines}\\
${contact_block}]

#v(${sp_sender})

// Recipient
${recip_lines}

#v(${sp_recip})

// Date
${date}

#v(${sp_date})

// Subject — bold
*${subject_escaped}*

#v(${sp_subject})

// Body
${body_typst}

#v(${sp_closing})

// Closing
${closing_escaped},

#v(${sp_signoff})

// Signoff
${signoff_escaped}
TYPST

    # Compile
    my ($tmp_fh, $tmp_path) = tempfile('cover-XXXX', SUFFIX => '.typ', TMPDIR => 1);
    binmode($tmp_fh, ':encoding(UTF-8)');
    print $tmp_fh $typst;
    close $tmp_fh;

    my @cmd = ('typst', 'compile', $tmp_path, $output);
    system(@cmd) == 0
        or die "Error: typst compile failed (exit $?)\n";

    unlink $tmp_path;
    return $output;
}

# Format a date string: "2025-10-31" → "31 October 2025"
# If unparseable, return as-is. If undef, return today.
sub _format_date {
    my ($date) = @_;

    if (!$date) {
        my @t = localtime;
        return sprintf('%d %s %d', $t[3], $MONTHS[$t[4]], $t[5] + 1900);
    }

    if ($date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
        my ($y, $m, $d) = ($1, $2, $3);
        my $month = $MONTHS[$m - 1] // $m;
        $d =~ s/^0//;
        return "$d $month $y";
    }

    # Unparseable — return as-is
    return $date;
}

sub _format_address {
    my ($addr) = @_;
    return '' unless $addr;
    my @parts = split /\s*\/\s*/, $addr;
    return join("\\\n", map { _escape_typst($_) } @parts);
}

sub _escape_typst {
    my ($text) = @_;

    # Convert org/markdown markup to Typst before escaping special chars
    my @markup_slots;

    # Markdown bold italic: ***text***
    $text =~ s{\*\*\*([^*\n]+?)\*\*\*}{
        push @markup_slots, "*_${1}_*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Markdown bold: **text**
    $text =~ s{\*\*([^*\n]+?)\*\*}{
        push @markup_slots, "*${1}*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org underline: _text_
    $text =~ s{(?<!\w)_([^_\n]+?)_(?!\w)}{
        my $inner = $1;
        $inner =~ s/\x00MARKUP(\d+)\x00/$markup_slots[$1]/g;
        push @markup_slots, "#underline[${inner}]";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org italic: /text/
    $text =~ s{(?<!\w)/([^/\n]+?)/(?!\w)}{
        push @markup_slots, "_${1}_";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;
    # Org bold: *text*
    $text =~ s{(?<!\w)\*([^*\n]+?)\*(?!\w)}{
        push @markup_slots, "*${1}*";
        "\x00MARKUP" . $#markup_slots . "\x00"
    }ge;

    # Escape Typst special characters
    $text =~ s/\\/\\\\/g;
    $text =~ s/_/\\_/g;
    $text =~ s/\*/\\*/g;
    $text =~ s/\$/\\\$/g;
    $text =~ s/#/\\#/g;
    $text =~ s/@/\\@/g;

    # Restore markup placeholders
    $text =~ s/\x00MARKUP(\d+)\x00/$markup_slots[$1]/g;

    return $text;
}

1;
