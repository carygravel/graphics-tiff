use Test::More tests => 3;
BEGIN { use_ok('Graphics::TIFF') };

#########################

is (TIFFTAG_IMAGEWIDTH,  256, "TIFFTAG_IMAGEWIDTH");
is (TIFFTAG_IMAGELENGTH, 257, "TIFFTAG_IMAGELENGTH");
