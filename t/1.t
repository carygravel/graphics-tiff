use warnings;
use strict;
use Test::More tests => 24;

BEGIN { use_ok('Graphics::TIFF') }

#########################

like( Graphics::TIFF->GetVersion, qr/LIBTIFF, Version/, 'version string' );

my $version = Graphics::TIFF->get_version_scalar;
isnt $version, undef, 'version';

SKIP: {
    skip 'libtiff 4.0.3 or better required', 20 unless $version >= 4.000003;

    system("convert rose: test.tif");

    my $tif = Graphics::TIFF->Open( 'test.tif', 'r' );
    isa_ok $tif, 'Graphics::TIFF';
    can_ok $tif, qw(Close ReadDirectory GetField);

    is( $tif->ReadDirectory, 0, 'ReadDirectory' );

    is( $tif->ReadEXIFDirectory(0), 0, 'ReadEXIFDirectory' );

    is( $tif->SetDirectory(0), 1, 'SetDirectory' );

    is( $tif->SetSubDirectory(0), 0, 'SetSubDirectory' );

    is( $tif->GetField(TIFFTAG_FILLORDER), FILLORDER_MSB2LSB, 'GetField' );
    my @counts = $tif->GetField(TIFFTAG_STRIPBYTECOUNTS);
    is_deeply( \@counts, [ 8190, 1470 ], 'GetField array of int' );

    is( $tif->SetField( TIFFTAG_FILLORDER, FILLORDER_LSB2MSB ),
        1, 'SetField status' );
    is( $tif->GetField(TIFFTAG_FILLORDER),
        FILLORDER_LSB2MSB, 'SetField result' );
    $tif->SetField( TIFFTAG_FILLORDER, FILLORDER_MSB2LSB );    # reset

    is( $tif->IsTiled, 0, 'IsTiled' );

    is( $tif->ScanlineSize, 210, 'ScanlineSize' );

    is( $tif->StripSize, 8190, 'StripSize' );

    is( $tif->NumberOfStrips, 2, 'NumberOfStrips' );

    is( $tif->TileSize, 8190, 'TileSize' );

    is( $tif->TileRowSize, 210, 'TileRowSize' );

    is( $tif->ComputeStrip( 16, 0 ), 0, 'ComputeStrip' );

    is( length( $tif->ReadEncodedStrip( 1, 20 ) ), 8190, 'ReadEncodedStrip' );

    is( length( $tif->ReadRawStrip( 1, 20 ) ), 8190, 'ReadRawStrip' );

    is( length( $tif->ReadTile( 0, 0, 0, 0 ) ), 8190, 'ReadTile' );

    my $filename = 'out.txt';
    open my $fh, '>', $filename;
    $tif->PrintDirectory( $fh, 0 );
    close $fh;
    is( -s $filename, 417, 'PrintDirectory' );
    unlink $filename;

    $tif->Close;
    unlink 'test.tif';
}
