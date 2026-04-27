# ABOUTME: Config-driven Typst template for stage play formatting.
# ABOUTME: All layout values read from Folio::Config; supports British and American styles.
package OrgPlay::TypstTemplate;

use strict;
use warnings;
use utf8;

our $VERSION = '0.2.0';

# Generate the Typst preamble with function definitions driven by config.
sub preamble {
    my ($class, %opts) = @_;

    my $config = $opts{config} or die "OrgPlay::TypstTemplate::preamble requires config\n";

    my $font      = $config->get('folio.font')      // 'New Computer Modern';
    my $font_size = $config->get('folio.font-size')  // '12pt';
    my $margin    = $config->get('folio.margin')     // '25mm';
    my $page      = $config->get('folio.page')       // 'a4';

    # Speech positioning
    my $speech_space   = $config->get('folio.positioning.speech.space-before')     // '1.6em';
    my $spk_bold       = $config->get('folio.positioning.speech.speaker.bold')     // 1;
    my $spk_italic     = $config->get('folio.positioning.speech.speaker.italic')   // 0;
    my $spk_case       = $config->get('folio.positioning.speech.speaker.case-transform') // 'small-caps';
    my $spk_prefix     = $config->get('folio.positioning.speech.speaker.prefix')   // '';
    my $spk_suffix     = $config->get('folio.positioning.speech.speaker.suffix')   // ':';
    my $spk_align      = $config->get('folio.positioning.speech.speaker.align')    // 'left';
    my $spk_indent     = $config->get('folio.positioning.speech.speaker.indent')   // '0';

    my $instr_place    = $config->get('folio.positioning.speech.speech-instruction.placement') // 'same-line';
    my $instr_italic   = $config->get('folio.positioning.speech.speech-instruction.italic')    // 1;
    my $instr_prefix   = $config->get('folio.positioning.speech.speech-instruction.prefix')    // '(';
    my $instr_suffix   = $config->get('folio.positioning.speech.speech-instruction.suffix')    // ')';

    my $dial_place     = $config->get('folio.positioning.speech.dialogue.placement')    // 'same-line';
    my $dial_indent    = $config->get('folio.positioning.speech.dialogue.indent')       // '0';
    my $dial_wrap      = $config->get('folio.positioning.speech.dialogue.wrap-indent')  // '5em';

    # Stage direction
    my $dir_space   = $config->get('folio.positioning.stage-direction.space-before') // '1.6em';
    my $dir_italic  = $config->get('folio.positioning.stage-direction.italic')       // 1;
    my $dir_align   = $config->get('folio.positioning.stage-direction.align')        // 'left';
    my $dir_indent  = $config->get('folio.positioning.stage-direction.indent')       // '0';

    # Transition
    my $trans_space  = $config->get('folio.positioning.transition.space-before') // '1.6em';
    my $trans_align  = $config->get('folio.positioning.transition.align')        // 'right';
    my $trans_case   = $config->get('folio.positioning.transition.case-transform') // 'upper';
    my $trans_indent = $config->get('folio.positioning.transition.indent')       // '0';

    # Act header
    my $act_align   = $config->get('folio.positioning.act-header.align')        // 'center';
    my $act_fsize   = $config->get('folio.positioning.act-header.font-size')    // '14pt';
    my $act_bold    = $config->get('folio.positioning.act-header.bold')         // 1;
    my $act_case    = $config->get('folio.positioning.act-header.case-transform') // 'as-written';
    my $act_space   = $config->get('folio.positioning.act-header.space-before') // '3em';

    # Scene header
    my $scn_align   = $config->get('folio.positioning.scene-header.align')        // 'left';
    my $scn_fsize   = $config->get('folio.positioning.scene-header.font-size')    // '12pt';
    my $scn_bold    = $config->get('folio.positioning.scene-header.bold')         // 1;
    my $scn_case    = $config->get('folio.positioning.scene-header.case-transform') // 'as-written';
    my $scn_space   = $config->get('folio.positioning.scene-header.space-before') // '2.5em';

    # Frontmatter header
    my $fm_align    = $config->get('folio.positioning.frontmatter.header.align')     // 'left';
    my $fm_fsize    = $config->get('folio.positioning.frontmatter.header.font-size') // '14pt';
    my $fm_bold     = $config->get('folio.positioning.frontmatter.header.bold')      // 1;
    my $fm_space    = $config->get('folio.positioning.frontmatter.header.space-before') // '2em';

    # Build Typst helper functions
    my $spk_weight = $spk_bold ? '"bold"' : '"regular"';
    my $spk_style  = $spk_italic ? '"italic"' : '"normal"';

    my $dir_open   = $dir_italic ? '_' : '';
    my $dir_close  = $dir_italic ? ' _' : '';
    my $dir_align_set = $dir_align ne 'left' ? "\n  set align($dir_align)" : '';

    my $act_weight = $act_bold ? '"bold"' : '"regular"';
    my $scn_weight = $scn_bold ? '"bold"' : '"regular"';
    my $fm_weight  = $fm_bold ? '"bold"' : '"regular"';

    # Precompute case-wrapped content strings
    my $spk_content = _case_wrap($spk_case, "${spk_prefix}#name${spk_suffix}");
    my $act_content = _case_wrap($act_case, '#title');
    my $scn_content = _case_wrap($scn_case, '#title');

    my $instr_open  = $instr_italic ? '_' : '';
    my $instr_close = $instr_italic ? '_' : '';

    # Dialogue block: British (same-line) vs American (new-line) layout
    my $dialogue_fn;
    if ($dial_place eq 'same-line') {
        $dialogue_fn = <<"TYPST";
#let dialogue(name, direction: none, body) = {
  block(above: ${speech_space}, below: 0.2em)[
    #if direction != none [
      #box(width: ${dial_wrap})[#text(weight: ${spk_weight})[${spk_content}]]${instr_open}${instr_prefix}#direction${instr_suffix}${instr_close}
      #block(inset: (left: ${dial_wrap}))[#body]
    ] else [
      #par(hanging-indent: ${dial_wrap})[
        #box(width: ${dial_wrap})[#text(weight: ${spk_weight})[${spk_content}]]#body
      ]
    ]
  ]
}
TYPST
    } else {
        # American: speaker centred, instruction below, dialogue indented
        $dialogue_fn = <<"TYPST";
#let dialogue(name, direction: none, body) = {
  block(above: ${speech_space}, below: 0.2em)[
    #align(${spk_align})[#text(weight: ${spk_weight})[${spk_content}]]
    #if direction != none [
      #align(${spk_align})[${instr_open}${instr_prefix}#direction${instr_suffix}${instr_close}]
    ]
    #block(inset: (left: ${dial_indent}))[#body]
  ]
}
TYPST
    }

    return <<"TYPST";
// Generated by First Folio
#set page(paper: "$page", margin: $margin, numbering: "1", number-align: center + bottom)
#set text(font: "$font", size: $font_size)
#set par(leading: 0.6em)

${dialogue_fn}
// Stage direction
#let stage-direction(body) = {${dir_align_set}
  block(above: ${dir_space}, below: 0.6em)[
    ${dir_open}#body${dir_close}
  ]
}

// Act header
#let act-header(title) = {
  v(${act_space})
  align(${act_align})[#text(size: ${act_fsize}, weight: ${act_weight})[${act_content}]]
  v(0.8em)
}

// Scene header
#let scene-header(title) = {
  v(${scn_space})
  align(${scn_align})[#text(size: ${scn_fsize}, weight: ${scn_weight})[${scn_content}]]
  v(0.5em)
}

// Prop text (signs, placards)
#let prop-text(body) = {
  align(center)[#text(style: "italic", weight: "bold")[#body]]
}

TYPST
}

# Generate the title page block, driven by config.
sub title_page {
    my ($class, %opts) = @_;

    my $config   = $opts{config};
    my $title    = $opts{title}    // '';
    my $subtitle = $opts{subtitle} // '';
    my $author   = $opts{author}   // '';
    my $date     = $opts{date}     // '';
    my $version  = $opts{version}  // '';

    return '' unless $title;

    # Read title page config
    my $tp_pagenum = $config ? $config->get('folio.title-page.page-number') : 0;

    my $t_align  = $config ? ($config->get('folio.title-page.title.align')     // 'center') : 'center';
    my $t_fsize  = $config ? ($config->get('folio.title-page.title.font-size') // '24pt')   : '24pt';
    my $t_bold   = $config ? ($config->get('folio.title-page.title.bold')      // 1)        : 1;
    my $t_italic = $config ? ($config->get('folio.title-page.title.italic')    // 0)        : 0;
    my $t_pos    = $config ? ($config->get('folio.title-page.title.position')  // 'third')  : 'third';

    my $st_fsize  = $config ? ($config->get('folio.title-page.subtitle.font-size')    // '14pt') : '14pt';
    my $st_italic = $config ? ($config->get('folio.title-page.subtitle.italic')       // 1)      : 1;
    my $st_space  = $config ? ($config->get('folio.title-page.subtitle.space-before') // '1em')  : '1em';

    my $a_fsize  = $config ? ($config->get('folio.title-page.author.font-size')    // '12pt') : '12pt';
    my $a_italic = $config ? ($config->get('folio.title-page.author.italic')       // 0)      : 0;
    my $a_prefix = $config ? ($config->get('folio.title-page.author.prefix')       // '')     : '';
    my $a_space  = $config ? ($config->get('folio.title-page.author.space-before') // '2em')  : '2em';

    my $d_pos    = $config ? ($config->get('folio.title-page.date.position')    // 'bottom-left')  : 'bottom-left';
    my $d_fsize  = $config ? ($config->get('folio.title-page.date.font-size')   // '10pt')         : '10pt';

    my $v_pos    = $config ? ($config->get('folio.title-page.version.position')  // 'bottom-right') : 'bottom-right';
    my $v_fsize  = $config ? ($config->get('folio.title-page.version.font-size') // '10pt')         : '10pt';

    # Build footer from date/version positions
    my ($footer_left, $footer_right) = ('none', 'none');

    my @footer_items = (
        [$version, $v_pos, $v_fsize],
        [$date,    $d_pos, $d_fsize],
    );
    for my $item (@footer_items) {
        my ($val, $pos, $fsize) = @$item;
        next unless $val;
        my $typst_text = "text(size: ${fsize})[${val}]";
        if ($pos eq 'bottom-left') {
            $footer_left = $typst_text;
        } elsif ($pos eq 'bottom-right') {
            $footer_right = $typst_text;
        }
    }

    my $has_footer = ($footer_left ne 'none' || $footer_right ne 'none');

    my $out = '';

    # Title page: configurable page number, custom footer
    if ($has_footer) {
        my $num = $tp_pagenum ? '"1"' : 'none';
        $out .= <<"TYPST";
#set page(numbering: $num, footer: grid(
  columns: (1fr, 1fr),
  align: (left, right),
  ${footer_left},
  ${footer_right},
))
TYPST
    } elsif (!$tp_pagenum) {
        $out .= "#set page(numbering: none)\n";
    }

    # Title position
    my $v_offset = $t_pos eq 'third' ? '30%' : '40%';

    my $t_weight = $t_bold ? ', weight: "bold"' : '';
    my $t_style  = $t_italic ? ', style: "italic"' : '';

    $out .= <<"TYPST";
#align(${t_align})[
  #v(${v_offset})
  #text(size: ${t_fsize}${t_weight}${t_style})[$title]
TYPST

    if ($subtitle) {
        my $st_style = $st_italic ? ', style: "italic"' : '';
        $out .= <<"TYPST";
  #v(${st_space})
  #text(size: ${st_fsize}${st_style})[$subtitle]
TYPST
    }

    if ($author) {
        my $a_style = $a_italic ? ', style: "italic"' : '';
        # Handle prefix with \n (e.g. "Written by\n")
        if ($a_prefix =~ /\\n/) {
            my @parts = split /\\n/, $a_prefix;
            for my $part (@parts) {
                next unless $part =~ /\S/;
                $out .= <<"TYPST";
  #v(${a_space})
  #text(size: ${a_fsize})[${part}]
TYPST
                $a_space = '0.3em';  # tighter spacing after first prefix line
            }
            $out .= <<"TYPST";
  #v(0.3em)
  #text(size: ${a_fsize}${a_style})[$author]
TYPST
        } else {
            $out .= <<"TYPST";
  #v(${a_space})
  #text(size: ${a_fsize}${a_style})[${a_prefix}$author]
TYPST
        }
    }

    $out .= <<'TYPST';
]
#pagebreak()
#set page(numbering: "1", number-align: center + bottom, footer: auto)

TYPST

    return $out;
}

# Wrap a Typst content expression with a case transform function.
# Returns "content" or "#upper[content]" etc.
sub _case_wrap {
    my ($case, $content) = @_;
    return "#upper[${content}]"     if $case eq 'upper';
    return "#smallcaps[${content}]" if $case eq 'small-caps';
    return "#lower[${content}]"     if $case eq 'lower';
    return $content;  # as-written: no transform
}

1;
