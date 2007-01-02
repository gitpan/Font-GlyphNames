#!perl 

use Test::More tests => 49;
use strict;



#--------------------------------------------------------------------#
# Test 1: See if the module loads

BEGIN { use_ok 'Font::GlyphNames' => "name2str" }


#--------------------------------------------------------------------#
# Tests 2 & 3: Object creation

ok our $gn = Font::GlyphNames->new, 'Create Font::GlyphNames object';
isa_ok $gn, 'Font::GlyphNames';


#--------------------------------------------------------------------#
# Tests 4-47: Examples from "Unicode and Glyph Names"

our %examples = (
	 Lcommaaccent => "\x{13b}",
	 uni20AC0308  => "\x{20ac}\x{308}",
	 u1040C       => "\x{1040C}",
	 uniD801DC0C  =>  undef,
	 uni20ac      =>  undef,
	'Lcommaaccent_uni20AC0308_u1040C.alternate' => "\x{13B}\x{20AC}\x{308}\x{1040C}",
	 uni013B      => "\x{13b}",
	 u013B        => "\x{13b}",
	 foo          =>  undef,
	'.notdef'     =>  undef,
);

our(@input,@output);
for(sort keys %examples) {
	push @input, $_;
	push @output, $examples{$_};
}

our $x = 1;
for (@input) {
	is_deeply scalar(name2str $_),       $examples{$_} , "Example $x, function, scalar context";
	is_deeply       [name2str $_],      [$examples{$_}], "Example $x, function, list context";
	is_deeply scalar($gn->name2str($_)), $examples{$_} , "Example $x, OO, scalar context";
	is_deeply       [$gn->name2str($_)],[$examples{$_}], "Example $x, OO, list context";
	++$x;
}
is_deeply       [name2str      @input],  \@output,   'All examples as a list';
is_deeply       [$gn->name2str(@input)], \@output,   'All examples as a list (OO)';
is_deeply scalar(name2str      @input),  $output[-1],'All examples as a list (scalar context)';
is_deeply scalar($gn->name2str(@input)), $output[-1],'All examples as a list (OO, scalar context)';


#--------------------------------------------------------------------#
# Tests 48 & 49: Custom file (instead of using a file, I'm going to
#                use STDIN input and pass '-' as the file name)

pipe STDIN, WH;
print WH <<END;

# IGNORE THIS LINE
 # AND THIS ONE

bill;2603
bob; 3020 

ChiRo;2627
snip-snip;2702 2701 2702 2701

END
close WH;

ok($gn = (new Font::GlyphNames '-'), 'Create object with custom glyph list file') or diag($@);
is_deeply [$gn->name2str(qw<bill bob ChiRo snip-snip>)], ["\x{2603}","\x{3020}","\x{2627}","\x{2702}\x{2701}"x2], 'custom object -> name2str';



