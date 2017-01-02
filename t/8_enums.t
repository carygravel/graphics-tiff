use Test::More tests => 4;
use warnings;
use strict;
BEGIN { use_ok('Graphics::TIFF') };

#########################

is (TIFFTAG_IMAGEWIDTH,  256, "TIFFTAG_IMAGEWIDTH");
is (TIFFTAG_IMAGELENGTH, 257, "TIFFTAG_IMAGELENGTH");
is (TIFFTAG_EXIFIFD, 34665, "TIFFTAG_EXIFIFD");
