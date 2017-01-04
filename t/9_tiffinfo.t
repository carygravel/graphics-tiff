use Test::More tests => 7;
use warnings;
use strict;

#########################

system('convert rose: rose: test.tif');
my $cmd = 'PERL5LIB="blib:blib/arch:lib:$PERL5LIB" perl examples/tiffinfo.pl';

is(`$cmd test.tif`, `tiffinfo test.tif`, 'basic multi-directory');

is(`$cmd -2 test.tif`, `tiffinfo -2 test.tif`, 'dirnum');

system('convert rose: test.tif');

is(`$cmd -d test.tif`, `tiffinfo -d test.tif`, '-d');

is(`$cmd -D test.tif`, `tiffinfo -D test.tif`, '-D');

is(`$cmd -d -f lsb2msb test.tif`, `tiffinfo -d -f lsb2msb test.tif`, '-f lsb2msb');

is(`$cmd -d -f msb2lsb test.tif`, `tiffinfo -d -f msb2lsb test.tif`, '-f msb2lsb');

is(`$cmd -c test.tif`, `tiffinfo -c test.tif`, '-c');

#########################

unlink 'test.tif';
