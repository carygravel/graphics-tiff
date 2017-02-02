use Test::More tests => 1;
use warnings;
use strict;

#########################

my $cmd = 'PERL5LIB="blib:blib/arch:lib:$PERL5LIB" perl examples/tiff2pdf.pl';

# strip '' from around ?, which newer glibc libraries seem to have added
my $expected = `tiff2pdf -? test.tif 2>&1`;
$expected =~ s/'\?'/?/xsm;
is( `$cmd -? test.tif 2>&1`, $expected, '-?' );

#########################

unlink 'test.tif';
