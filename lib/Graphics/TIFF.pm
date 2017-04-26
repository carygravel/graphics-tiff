package Graphics::TIFF;

use 5.008005;
use strict;
use warnings;
use Exporter ();
use base qw(Exporter);
use Readonly;
Readonly my $MINOR => 1000;
Readonly my $MICRO => 1_000_000;

# This allows declaration	use Graphics::TIFF ':all';
our %EXPORT_TAGS = (
    'all' => [
        qw(
          TIFFLIB_VERSION

          TIFFTAG_SUBFILETYPE
          FILETYPE_REDUCEDIMAGE
          FILETYPE_PAGE
          FILETYPE_MASK

          TIFFTAG_OSUBFILETYPE
          OFILETYPE_IMAGE
          OFILETYPE_REDUCEDIMAGE
          OFILETYPE_PAGE

          TIFFTAG_IMAGEWIDTH
          TIFFTAG_IMAGELENGTH

          TIFFTAG_BITSPERSAMPLE
          TIFFTAG_COMPRESSION
          COMPRESSION_NONE
          COMPRESSION_CCITTRLE
          COMPRESSION_CCITTFAX3
          COMPRESSION_CCITT_T4
          COMPRESSION_CCITTFAX4
          COMPRESSION_CCITT_T6
          COMPRESSION_LZW
          COMPRESSION_OJPEG
          COMPRESSION_JPEG
          COMPRESSION_T85
          COMPRESSION_T43
          COMPRESSION_NEXT
          COMPRESSION_CCITTRLEW
          COMPRESSION_PACKBITS
          COMPRESSION_THUNDERSCAN
          COMPRESSION_IT8CTPAD
          COMPRESSION_IT8LW
          COMPRESSION_IT8MP
          COMPRESSION_IT8BL
          COMPRESSION_PIXARFILM
          COMPRESSION_PIXARLOG
          COMPRESSION_DEFLATE
          COMPRESSION_ADOBE_DEFLATE
          COMPRESSION_DCS
          COMPRESSION_JBIG
          COMPRESSION_SGILOG
          COMPRESSION_SGILOG24
          COMPRESSION_JP2000
          COMPRESSION_LZMA

          TIFFTAG_PHOTOMETRIC
          PHOTOMETRIC_MINISWHITE
          PHOTOMETRIC_MINISBLACK
          PHOTOMETRIC_RGB
          PHOTOMETRIC_PALETTE
          PHOTOMETRIC_MASK
          PHOTOMETRIC_SEPARATED
          PHOTOMETRIC_YCBCR
          PHOTOMETRIC_CIELAB
          PHOTOMETRIC_ICCLAB
          PHOTOMETRIC_ITULAB
          PHOTOMETRIC_LOGL
          PHOTOMETRIC_LOGLUV

          TIFFTAG_FILLORDER
          FILLORDER_MSB2LSB
          FILLORDER_LSB2MSB

          TIFFTAG_DOCUMENTNAME
          TIFFTAG_IMAGEDESCRIPTION
          TIFFTAG_STRIPOFFSETS

          TIFFTAG_ORIENTATION
          ORIENTATION_TOPLEFT
          ORIENTATION_TOPRIGHT
          ORIENTATION_BOTRIGHT
          ORIENTATION_BOTLEFT
          ORIENTATION_LEFTTOP
          ORIENTATION_RIGHTTOP
          ORIENTATION_RIGHTBOT
          ORIENTATION_LEFTBOT

          TIFFTAG_SAMPLESPERPIXEL
          TIFFTAG_ROWSPERSTRIP
          TIFFTAG_STRIPBYTECOUNTS

          TIFFTAG_XRESOLUTION
          TIFFTAG_YRESOLUTION

          TIFFTAG_PLANARCONFIG
          PLANARCONFIG_CONTIG
          PLANARCONFIG_SEPARATE

          TIFFTAG_GROUP3OPTIONS
          TIFFTAG_T4OPTIONS
          GROUP3OPT_2DENCODING
          GROUP3OPT_UNCOMPRESSED
          GROUP3OPT_FILLBITS

          TIFFTAG_GROUP4OPTIONS
          TIFFTAG_T6OPTIONS
          GROUP4OPT_UNCOMPRESSED

          TIFFTAG_RESOLUTIONUNIT
          RESUNIT_NONE
          RESUNIT_INCH
          RESUNIT_CENTIMETER

          TIFFTAG_PAGENUMBER

          TIFFTAG_TRANSFERFUNCTION

          TIFFTAG_SOFTWARE
          TIFFTAG_DATETIME

          TIFFTAG_ARTIST

          TIFFTAG_PREDICTOR
          PREDICTOR_NONE
          PREDICTOR_HORIZONTAL
          PREDICTOR_FLOATINGPOINT

          TIFFTAG_WHITEPOINT
          TIFFTAG_PRIMARYCHROMATICITIES
          TIFFTAG_COLORMAP

          TIFFTAG_TILEWIDTH
          TIFFTAG_TILELENGTH

          TIFFTAG_INKSET
          INKSET_CMYK
          INKSET_MULTIINK

          TIFFTAG_EXTRASAMPLES
          EXTRASAMPLE_UNSPECIFIED
          EXTRASAMPLE_ASSOCALPHA
          EXTRASAMPLE_UNASSALPHA

          TIFFTAG_SAMPLEFORMAT
          SAMPLEFORMAT_UINT
          SAMPLEFORMAT_INT
          SAMPLEFORMAT_IEEEFP
          SAMPLEFORMAT_VOID
          SAMPLEFORMAT_COMPLEXINT
          SAMPLEFORMAT_COMPLEXIEEEFP

          TIFFTAG_INDEXED
          TIFFTAG_JPEGTABLES

          TIFFTAG_JPEGPROC
          JPEGPROC_BASELINE
          JPEGPROC_LOSSLESS

          TIFFTAG_JPEGIFOFFSET
          TIFFTAG_JPEGIFBYTECOUNT

          TIFFTAG_JPEGLOSSLESSPREDICTORS
          TIFFTAG_JPEGPOINTTRANSFORM
          TIFFTAG_JPEGQTABLES
          TIFFTAG_JPEGDCTABLES
          TIFFTAG_JPEGACTABLES

          TIFFTAG_YCBCRSUBSAMPLING

          TIFFTAG_REFERENCEBLACKWHITE

          TIFFTAG_OPIIMAGEID

          TIFFTAG_COPYRIGHT

          TIFFTAG_EXIFIFD

          TIFFTAG_ICCPROFILE

          TIFFTAG_JPEGQUALITY

          TIFFTAG_JPEGCOLORMODE
          JPEGCOLORMODE_RAW
          JPEGCOLORMODE_RGB

          TIFFTAG_JPEGTABLESMODE
          JPEGTABLESMODE_QUANT
          JPEGTABLESMODE_HUFF

          TIFFTAG_ZIPQUALITY

          TIFFPRINT_STRIPS
          TIFFPRINT_CURVES
          TIFFPRINT_COLORMAP
          TIFFPRINT_JPEGQTABLES
          TIFFPRINT_JPEGACTABLES
          TIFFPRINT_JPEGDCTABLES
          )
    ]
);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our $VERSION = '0.02';

require XSLoader;
XSLoader::load( 'Graphics::TIFF', $VERSION );

sub get_version {
    my ($version) = Graphics::TIFF->GetVersion;
    if ( $version =~ /LIBTIFF,[ ]Version[ ](\d+)[.](\d+)[.](\d+)/xsm ) {
        return $1, $2, $3;
    }
    return;
}

sub get_version_scalar {
    my (@version) = Graphics::TIFF->get_version;
    if ( defined $version[0] and defined $version[1] and defined $version[2] ) {
        return $version[0] + $version[1] / $MINOR + $version[2] / $MICRO;
    }
    return;
}

sub Open {    ## no critic (Capitalization)
    my ( $class, $path, $flags ) = @_;
    my $self =
      Graphics::TIFF->_Open( $path, $flags );  ## no critic (ProtectPrivateSubs)
    bless \$self, $class;
    return \$self;
}

1;
__END__

=head1 NAME

Graphics::TIFF - Perl extension for the libtiff library

=head1 VERSION

0.02

=head1 SYNOPSIS

Perl bindings for the libtiff library.
This module allows you to access TIFF images in a Perlish and
object-oriented way, freeing you from the casting and memory management in C,
yet remaining very close in spirit to original API.

=head1 DESCRIPTION

The Graphics::TIFF module allows a Perl developer to access TIFF images.
Find out more about libtiff at L<http://www.libtiff.org>.

=head1 SUBROUTINES/METHODS

=head2 Graphics::TIFF->get_version

Returns an array with the LIBTIFF_VERSION_(MAJOR|MINOR|MICRO) versions:

  join('.',Graphics::TIFF->get_version)

=head2 Graphics::TIFF->get_version_scalar

Returns an scalar with the LIBTIFF_VERSION_(MAJOR|MINOR|MICRO) versions combined
as per the Perl version numbering, i.e. libtiff 4.0.6 gives 4.000006. This allows
simple version comparisons.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

The LIBTIFF Standard Reference L<http://www.libtiff.org/libtiff.html> is a handy
companion. The Perl bindings follow the C API very closely, and the C reference
documentation should be considered the canonical source.

=head1 AUTHOR

Jeffrey Ratcliffe, E<lt>Jeffrey.Ratcliffe@gmail.comE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 by Jeffrey Ratcliffe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
