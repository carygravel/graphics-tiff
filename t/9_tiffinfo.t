use Test::More tests => 2;
use warnings;
use strict;

#########################

system('convert rose: rose: test.tif');
my $cmd = 'PERL5LIB="blib:blib/arch:lib:$PERL5LIB" perl examples/tiffinfo.pl';

is(`$cmd test.tif`, `tiffinfo test.tif`, 'basic multi-directory');

is(`$cmd -2 test.tif`, `tiffinfo -2 test.tif`, 'dirnum');

#########################

unlink 'test.tif';
