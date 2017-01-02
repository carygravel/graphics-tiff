#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF;

my ($dirnum, $showdata, $rawdata, $readdata);
my $optind = 0;
my $stoponerr = 1;

while (my $c = getopt("0123456789")) {
    if (ord($c) >= ord('0') and ord($c) <= ord('9')) {
        $dirnum = substr($ARGV[$optind-1], 1);
    }
    elsif ($c eq 'd') {
        $showdata++;
        $readdata++;
    }
}

my $multiplefiles = @ARGV - $optind > 1;
while ($optind < @ARGV) {
    if ($multiplefiles) { print "$ARGV[$optind]\n" }
    my $tif = Graphics::TIFF->Open($ARGV[$optind], 'rc');
    if (defined $tif) {
        if (defined $dirnum) {
            if ($tif->SetDirectory($dirnum)) {
                tiffinfo($tif, 0, 0, 1);
            }
        }
        else {
            do {
                tiffinfo($tif, 0, 0, 1);
                my $offset = $tif->GetField(TIFFTAG_EXIFIFD);
                if (defined $offset) {
                    if ($tif->ReadEXIFDirectory($offset)) {
                        tiffinfo($tif, 0, 0, 0);
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
        $c = substr($ARGV[$optind], 1, 1);
        $optind++;
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
        ReadData($tif);
    }
    return;
}
