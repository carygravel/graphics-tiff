#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF;

my $multiplefiles = @ARGV > 1;
for my $file (@ARGV) {
    if ($multiplefiles) { print "$file\n" }
    my $tif = Graphics::TIFF->Open($file, 'rc');
    if (defined $tif) {
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
    $tif->Close;
}

sub tiffinfo {
    my ($tif, $order, $flags, $is_image) = @_;
    $tif->PrintDirectory(*STDOUT, $flags);
    return;
}
