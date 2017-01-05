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
          TIFFTAG_IMAGEWIDTH
          TIFFTAG_IMAGELENGTH
          TIFFTAG_FILLORDER
          FILLORDER_MSB2LSB
          FILLORDER_LSB2MSB
          TIFFTAG_ROWSPERSTRIP
          TIFFTAG_STRIPBYTECOUNTS
          TIFFTAG_XRESOLUTION
          TIFFTAG_YRESOLUTION
          TIFFTAG_PLANARCONFIG
          PLANARCONFIG_CONTIG
          TIFFTAG_PAGENUMBER
          TIFFTAG_EXIFIFD
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

our $VERSION = '0.01';
our $DEBUG   = 0;

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

sub Open {
    my ( $class, $path, $flags ) = @_;
    my $self =
      Graphics::TIFF->_Open( $path, $flags );  ## no critic (ProtectPrivateSubs)
    bless( \$self, $class );
    return \$self;
}

1;
__END__

=head1 NAME

Graphics::TIFF - Perl extension for the libtiff library

=head1 VERSION

0.01

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
