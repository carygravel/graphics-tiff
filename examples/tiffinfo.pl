#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

my ($optarg, $dirnum, $showdata, $rawdata, $readdata);
my $flags = 0;
my $optind = 0;
my $order = 0;
my $stoponerr = 1;

while (my $c = getopt("f:cdD0123456789")) {
    given ( $c ) {
        when (/[0-9]/xsm) {
            $dirnum = substr($ARGV[$optind-1], 1);
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
            if ($optarg eq 'lsb2msb' ) {
                $order = FILLORDER_LSB2MSB;
            }
            elsif ($optarg eq 'msb2lsb' ) {
                $order = FILLORDER_MSB2LSB;
            }
        }
        default {
            usage();
        }
    }
}

my $multiplefiles = @ARGV - $optind > 1;
while ($optind < @ARGV) {
    if ($multiplefiles) { print "$ARGV[$optind]\n" }
    my $tif = Graphics::TIFF->Open($ARGV[$optind], 'rc');
    if (defined $tif) {
        if (defined $dirnum) {
            if ($tif->SetDirectory($dirnum)) {
                tiffinfo($tif, $order, $flags, 1);
            }
        }
        else {
            do {
                tiffinfo($tif, $order, $flags, 1);
                my $offset = $tif->GetField(TIFFTAG_EXIFIFD);
                if (defined $offset) {
                    if ($tif->ReadEXIFDirectory($offset)) {
                        tiffinfo($tif, $order, $flags, 0);
                    }
                }
            } while ($tif->ReadDirectory);
        }
    }
    $optind++;
    $tif->Close;
}

sub getopt {
    my ($options) = @_;
    my $c;
    if (substr($ARGV[$optind], 0, 1) eq '-') {
        $c = substr($ARGV[$optind++], 1, 1);
        if ($options =~ /$c(:)?/xsm) {
            if (defined $1) { $optarg = $ARGV[$optind++] }
        }
        else {
            undef $c;
            $optind = $#ARGV + 1;
        }
    }
    return $c
}

sub ShowStrip {
    my ($strip, $pp, $nrow, $scanline) = @_;

    printf("Strip %lu:\n", $strip);
    my $i = 0;
    while ($nrow-- > 0) {
        for (my $cc = 0; $cc < $scanline; $cc++) {
            printf(" %02x", ord(substr($pp, $i++, 1)));
            if ((($cc+1) % 24) == 0) {
                print "\n";
            }
        }
        print "\n";
    }
}

sub ReadContigStripData {
    my ($tif) = @_;

    my $scanline = $tif->ScanlineSize;
    my $h = $tif->GetField(TIFFTAG_IMAGELENGTH);
    my $rowsperstrip = $tif->GetField(TIFFTAG_ROWSPERSTRIP);
    for (my $row = 0; $row < $h; $row += $rowsperstrip) {
        my $nrow = ($row+$rowsperstrip > $h ? $h-$row : $rowsperstrip);
        my $strip = $tif->ComputeStrip($row, 0);
        if (not (my $buf = $tif->ReadEncodedStrip($strip, $nrow*$scanline))) {
            if ($stoponerr) { last }
        }
        elsif ($showdata) {
            ShowStrip($strip, $buf, $nrow, $scanline);
        }
    }
}

sub ReadData {
    my ($tif) = @_;

    my $config = $tif->GetField(TIFFTAG_PLANARCONFIG);

    if ($tif->IsTiled) {
        if ($config == PLANARCONFIG_CONTIG) {
            TIFFReadContigTileData($tif);
        }
        else {
            TIFFReadSeparateTileData($tif);
        }
    }
    else {
        if ($config == PLANARCONFIG_CONTIG) {
            ReadContigStripData($tif);
        }
        else {
            ReadSeparateStripData($tif);
	}
    }
}

sub tiffinfo {
    my ($tif, $order, $flags, $is_image) = @_;
    $tif->PrintDirectory(*STDOUT, $flags);
    if (not $readdata or not $is_image) { return }
    if ($rawdata) {
    }
    else {
        if ($order) { $tif->SetField(TIFFTAG_FILLORDER, $order) }
        ReadData($tif);
    }
    return;
}
