use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Font::GlyphNames',
    AUTHOR              => 'Father Chrysostomos',
    VERSION_FROM        => 'lib/Font/GlyphNames.pm',
    ABSTRACT_FROM       => 'lib/Font/GlyphNames.pm',
    PL_FILES            => {},
#    PREREQ_PM => {
#        'Test::More' => 0,
#    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Font-GlyphNames-*' },
);
