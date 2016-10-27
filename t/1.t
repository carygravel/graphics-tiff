use warnings;
use strict;
use Test::More tests => 5;

BEGIN { use_ok('Graphics::TIFF') };

#########################

like( Graphics::TIFF->GetVersion, qr/LIBTIFF, Version/, 'version string' );

my $version = Graphics::TIFF->get_version_scalar;
isnt $version, undef, 'version';

SKIP: {
    skip 'libtiff 4.0.6 or better required', 2 unless $version >= 4.000006;

    system("convert rose: test.tif");

    my $tif = Graphics::TIFF->Open('test.tif', 'r');
    isa_ok $tif, 'Graphics::TIFF';
    can_ok $tif, qw(Close);

    unlink 'test.tif'
};
