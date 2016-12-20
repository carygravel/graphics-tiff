use warnings;
use strict;
use Test::More tests => 9;

BEGIN { use_ok('Graphics::TIFF') };

#########################

like( Graphics::TIFF->GetVersion, qr/LIBTIFF, Version/, 'version string' );

my $version = Graphics::TIFF->get_version_scalar;
isnt $version, undef, 'version';

SKIP: {
    skip 'libtiff 4.0.3 or better required', 6 unless $version >= 4.000003;

    system("convert rose: test.tif");

    my $tif = Graphics::TIFF->Open('test.tif', 'r');
    isa_ok $tif, 'Graphics::TIFF';
    can_ok $tif, qw(Close ReadDirectory GetField);

    is($tif->ReadDirectory, 0, 'ReadDirectory');

    is($tif->GetField(TIFFTAG_IMAGEWIDTH), 70, 'GetField');

    is($tif->ScanlineSize, 210, 'ScanlineSize');

    is($tif->StripSize, 8190, 'StripSize');

    $tif->Close;
    unlink 'test.tif'
};
