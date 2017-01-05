#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF ':all';
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

my ( $optarg, $showdata, $rawdata, $showwords, $readdata );
my $optind    = 0;
my $stoponerr = 1;

sub main {
    my $dirnum;
    my $flags  = 0;
    my $order  = 0;
    my $diroff = 0;

    while ( my $c = getopt("f:o:cdDijrs0123456789") ) {
        given ($c) {
            when (/[0-9]/xsm) {
                $dirnum = substr( $ARGV[ $optind - 1 ], 1 );
            }
            when ('c') {
                $flags |= TIFFPRINT_COLORMAP | TIFFPRINT_CURVES;
            }
            when ('d') {
                $showdata++;
                $readdata++;
            }
            when ('D') {
                $readdata++;
            }
            when ('f') {
                if ( $optarg eq 'lsb2msb' ) {
                    $order = FILLORDER_LSB2MSB;
                }
                elsif ( $optarg eq 'msb2lsb' ) {
                    $order = FILLORDER_MSB2LSB;
                }
            }
            when ('i') {
                $stoponerr = 0;
            }
            when ('j') {
                $flags |=
                  TIFFPRINT_JPEGQTABLES | TIFFPRINT_JPEGACTABLES |
                  TIFFPRINT_JPEGDCTABLES;
            }
            when ('o') {
                $diroff = $optarg;
            }
            when ('r') {
                $rawdata = 1;
            }
            when ('s') {
                $flags |= TIFFPRINT_STRIPS;
            }
            default {
                usage();
            }
        }
    }

    my $multiplefiles = @ARGV - $optind > 1;
    while ( $optind < @ARGV ) {
        if ($multiplefiles) { print "$ARGV[$optind]\n" }
        my $tif = Graphics::TIFF->Open( $ARGV[$optind], 'rc' );
        if ( defined $tif ) {
            if ( defined $dirnum ) {
                if ( $tif->SetDirectory($dirnum) ) {
                    tiffinfo( $tif, $order, $flags, 1 );
                }
            }
            elsif ( $diroff != 0 ) {
                if ( $tif->SetSubDirectory($diroff) ) {
                    tiffinfo( $tif, $order, $flags, 1 );
                }
            }
            else {
                do {
                    tiffinfo( $tif, $order, $flags, 1 );
                    my $offset = $tif->GetField(TIFFTAG_EXIFIFD);
                    if ( defined $offset ) {
                        if ( $tif->ReadEXIFDirectory($offset) ) {
                            tiffinfo( $tif, $order, $flags, 0 );
                        }
                    }
                } while ( $tif->ReadDirectory );
            }
        }
        $optind++;
        $tif->Close;
    }
    return 0;
}

sub getopt {
    my ($options) = @_;
    my $c;
    if ( substr( $ARGV[$optind], 0, 1 ) eq '-' ) {
        $c = substr( $ARGV[ $optind++ ], 1, 1 );
        if ( $options =~ /$c(:)?/xsm ) {
            if ( defined $1 ) { $optarg = $ARGV[ $optind++ ] }
        }
        else {
            undef $c;
            $optind = $#ARGV + 1;
        }
    }
    return $c;
}

sub ShowStrip {
    my ( $strip, $pp, $nrow, $scanline ) = @_;

    printf( "Strip %lu:\n", $strip );
    my $i = 0;
    while ( $nrow-- > 0 ) {
        for ( my $cc = 0 ; $cc < $scanline ; $cc++ ) {
            printf( " %02x", ord( substr( $pp, $i++, 1 ) ) );
            if ( ( ( $cc + 1 ) % 24 ) == 0 ) {
                print "\n";
            }
        }
        print "\n";
    }
    return;
}

sub ReadContigStripData {
    my ($tif) = @_;

    my $scanline     = $tif->ScanlineSize;
    my $h            = $tif->GetField(TIFFTAG_IMAGELENGTH);
    my $rowsperstrip = $tif->GetField(TIFFTAG_ROWSPERSTRIP);
    for ( my $row = 0 ; $row < $h ; $row += $rowsperstrip ) {
        my $nrow = ( $row + $rowsperstrip > $h ? $h - $row : $rowsperstrip );
        my $strip = $tif->ComputeStrip( $row, 0 );
        if (
            not( my $buf = $tif->ReadEncodedStrip( $strip, $nrow * $scanline ) )
          )
        {
            if ($stoponerr) { last }
        }
        elsif ($showdata) {
            ShowStrip( $strip, $buf, $nrow, $scanline );
        }
    }
    return;
}

sub ReadData {
    my ($tif) = @_;

    my $config = $tif->GetField(TIFFTAG_PLANARCONFIG);

    if ( $tif->IsTiled ) {
        if ( $config == PLANARCONFIG_CONTIG ) {
            TIFFReadContigTileData($tif);
        }
        else {
            TIFFReadSeparateTileData($tif);
        }
    }
    else {
        if ( $config == PLANARCONFIG_CONTIG ) {
            ReadContigStripData($tif);
        }
        else {
            ReadSeparateStripData($tif);
        }
    }
    return;
}

sub ShowRawBytes {
    my ( $pp, $n ) = @_;

    for ( my $i = 0 ; $i < $n ; $i++ ) {
        printf( " %02x", ord( substr( $pp, $i, 1 ) ) );
        if ( ( ( $i + 1 ) % 24 ) == 0 ) { print "\n " }
    }
    print "\n";
    return;
}

sub ShowRawWords {
    my ( $pp, $n ) = @_;

    for ( my $i = 0 ; $i < $n ; $i++ ) {
        printf( " %04x", ord( substr( $pp, $i, 1 ) ) );
        if ( ( ( $i + 1 ) % 15 ) == 0 ) { print "\n " }
    }
    print "\n";
    return;
}

sub ReadRawData {
    my ( $tif, $bitrev ) = @_;

    my $nstrips = $tif->NumberOfStrips();
    my $what = $tif->IsTiled() ? "Tile" : "Strip";

    my @stripbc = $tif->GetField(TIFFTAG_STRIPBYTECOUNTS);
    if ( $nstrips > 0 ) {

        for my $s ( 0 .. $#stripbc ) {
            my $buf;
            if ( $buf = $tif->ReadRawStrip( $s, $stripbc[$s] ) ) {
                if ($showdata) {
                    if ($bitrev) {
                        TIFFReverseBits( $buf, $stripbc[$s] );
                        printf( "%s %lu: (bit reversed)\n ", $what, $s );
                    }
                    else {
                        printf( "%s %lu:\n ", $what, $s );
                    }
                    if ($showwords) {
                        ShowRawWords( $buf, $stripbc[$s] >> 1 );
                    }
                    else {
                        ShowRawBytes( $buf, $stripbc[$s] );
                    }
                }
            }
            else {
                fprintf( *STDERR, "Error reading strip %lu\n", $s );
                if ($stoponerr) { last }
            }
        }
    }
    return;
}

sub tiffinfo {
    my ( $tif, $order, $flags, $is_image ) = @_;
    $tif->PrintDirectory( *STDOUT, $flags );
    if ( not $readdata or not $is_image ) { return }
    if ($rawdata) {
        if ($order) {
            my $o = $tif->GetFieldDefaulted(TIFFTAG_FILLORDER);
            ReadRawData( $tif, $o != $order );
        }
        else {
            ReadRawData( $tif, 0 );
        }
    }
    else {
        if ($order) { $tif->SetField( TIFFTAG_FILLORDER, $order ) }
        ReadData($tif);
    }
    return;
}

exit main();
