use Test::More tests => 2;
use warnings;
use strict;

#########################

my $cmd = 'PERL5LIB="blib:blib/arch:lib:$PERL5LIB" perl examples/tiff2pdf.pl';
my $tif = 'test.tif';

# strip '' from around ?, which newer glibc libraries seem to have added
my $expected = `tiff2pdf -? $tif 2>&1`;
$expected =~ s/'\?'/?/xsm;
is( `$cmd -? $tif 2>&1`, $expected, '-?' );

#########################

system("convert -density 72 rose: $tif");
system("tiff2pdf -d -o C.pdf $tif");

my $make_reproducible =
'grep --binary-files=text -v "/ID" | grep --binary-files=text -v "/CreationDate" | grep --binary-files=text -v "/ModDate" | grep --binary-files=text -v "/Producer"';
$expected = `cat C.pdf | $make_reproducible | hexdump`;

my @expected = split "\n", $expected;
my @output   = split "\n", `$cmd -d $tif | $make_reproducible | hexdump`;

is_deeply( \@output, \@expected, 'basic functionality' );

#########################

unlink 'test.tif', 'C.pdf';
