use warnings;
use strict;
use Graphics::TIFF ':all';
use Test::More tests => 32;
BEGIN { use_ok('Graphics::TIFF') }

#########################

like( Graphics::TIFF->GetVersion, qr/LIBTIFF, Version/, 'version string' );

my $version = Graphics::TIFF->get_version_scalar;
isnt $version, undef, 'version';

SKIP: {
    skip 'libtiff 4.0.3 or better required', 29 unless $version >= 4.000003;

    ok( Graphics::TIFF->IsCODECConfigured(COMPRESSION_DEFLATE),
        'IsCODECConfigured' );

    system("convert -density 72 rose: test.tif");

    my $tif = Graphics::TIFF->Open( 'test.tif', 'r' );
    is( $tif->FileName, 'test.tif', 'FileName' );
    isa_ok $tif, 'Graphics::TIFF';
    can_ok $tif, qw(Close ReadDirectory GetField);

    is( $tif->ReadDirectory, 0, 'ReadDirectory' );

    is( $tif->ReadEXIFDirectory(0), 0, 'ReadEXIFDirectory' );

    is( $tif->NumberOfDirectories, 1, 'NumberOfDirectories' );

    is( $tif->SetDirectory(0), 1, 'SetDirectory' );

    is( $tif->SetSubDirectory(0), 0, 'SetSubDirectory' );

    is( $tif->GetField(TIFFTAG_FILLORDER),
        FILLORDER_MSB2LSB, 'GetField uint16' );
    is( $tif->GetField(TIFFTAG_XRESOLUTION), 72, 'GetField float' );
    my @counts = $tif->GetField(TIFFTAG_PAGENUMBER);
    is_deeply( \@counts, [ 0, 1 ], 'GetField 2 uint16' );
    @counts = $tif->GetField(TIFFTAG_STRIPBYTECOUNTS);
    is_deeply( \@counts, [ 8190, 1470 ], 'GetField array of uint64' );
    is( $tif->GetField(TIFFTAG_IMAGEWIDTH), 70, 'GetField uint32' );

    @counts = $tif->GetField(TIFFTAG_PRIMARYCHROMATICITIES);
    is_deeply(
        \@counts,
        [
            0.639999985694885, 0.330000013113022,
            0.300000011920929, 0.600000023841858,
            0.150000005960464, 0.0599999986588955
        ],
        'GetField array of float'
    );

    is( $tif->GetFieldDefaulted(TIFFTAG_FILLORDER),
        FILLORDER_MSB2LSB, 'GetFieldDefaulted uint16' );

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
    is( -s $filename, 449, 'PrintDirectory' );
    unlink $filename;

    $tif->Close;

#########################

    unlink 'test.tif';
}
