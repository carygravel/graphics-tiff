#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF;

my ($dirnum);
my $optind = 0;
while (my $c = getopt("0123456789")) {
    if ($c >= 0 and $c <= 9) {
        $dirnum = substr($ARGV[$optind-1], 1);
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

sub tiffinfo {
    my ($tif, $order, $flags, $is_image) = @_;
    $tif->PrintDirectory(*STDOUT, $flags);
    return;
}
