package Font::GlyphNames;

require 5.008;
use strict;
use warnings;

use File::Spec::Functions 'catfile';
use Encode 'decode';

require Exporter;

our($VERSION)   =  0.02;
our(@ISA)       = 'Exporter';
our(@EXPORT_OK) = qw[
	name2str
	name2code
	str2name
	code2name
	code2ligname
];

our $_obj;  # object used by the function-oriented interface
our @LISTS = qw[ zapfdingbats.txt
                 glyphlist.txt   ];
our @PATH  = split /::/, __PACKAGE__;
# our $NULL = ''; # ~~~ to be implemented

use subs qw[
	_read_glyphlist
];


=head1 NAME

Font::GlyphNames - Convert between glyph names and characters

=head1 VERSION

Version .02

B<WARNING:> This is a pre-alpha release. The API is subject to change 
without
notice. Some of the features (those
commented out in the synopsis) have not
yet been implemented.

=head1 SYNOPSIS

  use Font::GlyphNames qw[
                           name2str
                           name2code
                           str2name
                           code2name
                           code2ligname
                         ];
  
  name2str qw[one two three s_t Psi uni00D4];
  # name2code    qw[one two three s_t Psi uni00D4]
  # str2name     qw[1 2 3 st E<0x3A8> E<Ocirc>];
  # code2name    qw[49 50 51 115 116 936 212];
  # code2ligname qw[49 50 51 115 116 936 212];

  # Or you can use the OO interface:
  
  use Font::GlyphNames;
  
  $gn = new Font::GlyphNames; # use default glyph list
  $gn = new Font::GlyphNames 'my-glyphs.txt'; # custom list

  $gn->name2code(qw[ a slong_slong_i s_t.alt ]);
  # etc.
  
=head1 DESCRIPTION

This module uses the Adobe Glyph Naming convention (see L<SEE ALSO>) for converting
between glyph names and characters (or character codes).

=head1 METHODS/FUNCTIONS

Except for C<new> (which is only a method), each item listed 
here is
both a function and a method.

=over 4

=item new ( LIST )

This class method constructs and returns a new Font::GlyphNames object.
If an error occurs, it returns undef (check C<$@> for the error; note
also that C<new()> clobbers any existing value of C<$@>, whether there
is an error or not). LIST is a
list of files to use as a glyph list. If LIST is
omitted, the Zapf Dingbats Glyph List and the Adobe
Glyph List (see L<SEE ALSO>) will be used instead.

=cut

# ~~~ I need to make it so that new() takes two types of arg lists:
# 1)   new( FILES )
# 2)   new( { lists => \@files, search_inc => 1 } )
#   or new( { list => $file,    search_inc => 1 } )
#
# If list and lists are both specified, it will be understood as
# lists => [@$lists, $list]

sub new {
	my($class, $self, $search_inc) = (shift || __PACKAGE__, {});
	my @lists = @_ ? @_ : @{$search_inc = 1, \@LISTS};

	# read the glyph list(s) into $$self{name2code};
	$$self{name2code} = {};
	eval { for (reverse @lists) {
		%{$$self{name2code}} = (
		    %{$$self{name2code}},
		    %{ _read_glyphlist $_, {search_inc => $search_inc} }
		);
	}};
	return if $@ ne '';
	
	# create the reverse mapping in $$self{code2name}
	for (keys %{$$self{name2code}}) {
		$$self{code2name}{$$self{name2code}{$_}[0]} = $_
		unless @{$$self{name2code}{$_}} > 1 or
		    exists $$self{code2name}{$$self{name2code}{$_}[0]};
	}
	# ~~~ The reverse mapping needs to support ligatures:
	# $$self{code2name}{'05D3_05B2'} = 'dalethatafpatah';

	bless $self, $class;
}

=item name2str ( LIST )

LIST is a list of glyph names. This function returns a list of the
string equivalents of the glyphs in list context, or the string
equivalent of the I<last> item in scalar context. Invalid glyph
names and names beginning with a dot (chr 0x2E) produce undef. Some 
examples (in
list context):

  name2str   's_t'             # returns 'st'
  name2str qw/Psi uni00D4/     # returns ("\x{3a8}", "\xd4")
  name2str   '.notdef'         # returns undef
  name2str   'uni12345678'     # returns "\x{1234}\x{5678}"
  name2str qw/one uni32 three/ # returns ('one', undef, 'three')

If, for invalid glyph names, you would like something other than undef 
(the null char, for instance), you can replace it afterwards easily 
enough:

  map +("\0",$_)[defined], name2str ...

=cut

sub name2str {
	my $self = &_get_self;
	my(@names,@ret,$str) = @_;
	for(@names) {
		s/\..*//s;
		$str = undef;
		for (split /_/) {
			# Here we check each type of glyph name
			if (exists $$self{name2code}{$_}) {
				$str .= join '', map chr, 
					@{$$self{name2code}{$_}};
			}
			elsif (/^uni( 
				  (?: #non-surrogate codepoints:
				    [\dA-CEF][\dA-F]{3}
				      |
				    D[0-7][\dA-F]{2}
				  )+
				)\z/x) {
				$str .= decode 'UTF-16BE', pack 'H*', $1;
			}
			elsif (/^u(
				  [\dA-CEF][\dA-F]{3}
				    |	
				  D[0-7][\dA-F]{2}
				    |
				  [\dA-F]{5,6}
				)\z/x) {
				$str .= chr hex $1;
			}
			# no else necessary because $str is already undef
		}
		push @ret, $str;
	}
	wantarray ? @ret : $ret[-1];
}


=item name2code ( LIST )

=item str2name ( LIST )

=item code2name ( LIST )

=item code2ligname ( LIST )

These have yet to be implemented.

=back

=cut
   



#----------- PRIVATE SUBROUTINES ---------------#

# _read_glyphlist(filename, { search_inc => bool} ) reads a glyph list
# file and returns a hashref like
# this: { glyphname => charcode, glyphname => charcode, ... }

sub _read_glyphlist {
	my($file, $opts) = @_;
	my(%h,$fh);
	
	if($$opts{search_inc}) {
		my $f;
		# I pilfered this code from  Unicode::Collate  (and
		# modified it slightly).
		for (@INC) { 
			$f = catfile $_, @PATH, $file;
			last if open $fh, $f;
			$f = undef;
		}
		defined $f or die "$f cannot be found in \@INC (\@INC contains @INC).";
	}
	else {
		open $fh, $file or die "$file could not be opened: $!";
	}
	
	my $line; for ($line) {
	while (<$fh>) {
		next if /^\s*(?:#|\z)/;
		s/^\cj//; # for Mac Classic compatibility
		/^([^;]+);\s*([\da-f][\da-f\s]+)\z/i
			or die "Invalid glyph list line in $file: $_ ";
		$h{$1} = [map hex, split ' ', $2];
	}}
	\%h;
}


# _get_self helps the methods act as functions as well.
# Each function should call it thusly:
#	my $self = &_get_self;
# The object (if any) will be shifted off @_.
# If there was no object in @_, $self will refer to $_obj (a
# package var.)

sub _get_self {
	UNIVERSAL::isa($_[0], __PACKAGE__)
	?	shift
	:	($_obj ||= new);
}


#----------- THE REST OF THE DOCUMENTATION ---------------#

=pod

=head1 THE GLYPH LIST FILE FORMAT

B<Note:> This section is not intended to be normative. It simply
describes how this module parses glyph list files--which works with
those provided by Adobe.

All lines that consist solely of
whitespace or that have a sharp sign (#) preceded only by whitespace
(if any) are ignored. All others lines must consist of the glyph name
followed by a semicolon, and the character numbers in hex, separated
and optionally
surrounded by whitespace. If there are multiple character numbers, the
glyph is understood to represent a sequence of characters. The line
breaks must be either CRLF sequences 
(as in
Adobe's
lists) or native line breaks.
If a glyph name occurs more than once, the first instance
will be
used.


=head1 COMPATIBILITY

This module requires perl 5.8.0 or later. Though it should work in
Windows, MacPerl, and any Unix flavour, I have only tested it in perl
5.8.6 on Mac OS X 10.4 (Darwin 8).

=head1 BUGS

C<name2str> does not properly validate glyph names consisting of "u"
followed by five or six hex digits. Specifically, it lets surrogates
(such as u0D800) and characters above U+10FFFF (e.g., u120000)
through.

Please e-mail me if you find any other bugs.

=head1 AUTHOR

Father Chrysostomos <join '', name2str qw[s p r o u t at c p a n
period o r g]>

=head1 SEE ALSO

=over 4

=item B<Unicode and Glyph Names> 

L<http://partners.adobe.com/public/developer/opentype/index_glyph.html>

=item B<Glyph Names and Current Implementations>

L<http://partners.adobe.com/public/developer/opentype/index_glyph2.html>

=item B<Adobe Glyph List>

L<http://partners.adobe.com/public/developer/en/opentype/glyphlist.txt>

=item B<ITC Zapf Dingbats Glyph List>

L<http://partners.adobe.com/public/developer/en/opentype/zapfdingbats.txt>

=cut




