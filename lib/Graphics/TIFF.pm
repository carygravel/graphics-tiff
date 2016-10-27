package Graphics::TIFF;

use 5.008005;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# This allows declaration	use Graphics::TIFF ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
);

our $VERSION = '0.01';
our $DEBUG = 0;
our ($STATUS, $_status, $_vc);

require XSLoader;
XSLoader::load('Graphics::TIFF', $VERSION);

sub get_version {
    my ($version) = Graphics::TIFF->GetVersion;
    if ($version =~ /LIBTIFF,[ ]Version[ ](\d+)[.](\d+)[.](\d+)/xsm) {
        return $1, $2, $3;
    }
    return;
}

sub get_version_scalar {
    my (@version) = Graphics::TIFF->get_version;
    if (defined $version[0] and defined $version[1] and defined $version[2]) {
        return $version[0] + $version[1]/1000 + $version[2]/1000000;
    }
    return;
}

sub Open {
    my ($class, $path, $flags) = @_;
    my $self = Graphics::TIFF->_Open($path, $flags);
    bless (\$self, $class);
    return \$self;
}

1;
__END__

=head1 NAME

Graphics::TIFF - Perl extension for the libtiff library

=head1 SYNOPSIS

=head1 ABSTRACT

Perl bindings for the libtiff library.
This module allows you to access TIFF images in a Perlish and
object-oriented way, freeing you from the casting and memory management in C,
yet remaining very close in spirit to original API.

=head1 DESCRIPTION

The Graphics::TIFF module allows a Perl developer to access TIFF images.
Find out more about libtiff at L<http://www.>.

Most methods set $Graphics::TIFF::STATUS, which is overloaded to give either an integer
as dictated by the LIBTIFF standard, or the the corresponding message, as required.

=head2 Graphics::TIFF->get_version

Returns an array with the LIBTIFF_VERSION_(MAJOR|MINOR|BUILD) versions:

  join('.',Graphics::TIFF->get_version)

=head2 Graphics::TIFF->get_version_scalar

Returns an scalar with the LIBTIFF_VERSION_(MAJOR|MINOR|BUILD) versions combined
as per the Perl version numbering, i.e. libtiff 4.0.6 gives 4.000006. This allows
simple version comparisons.

=head1 SEE ALSO

The LIBTIFF Standard Reference L<http://www.libtiff-project.org/html> is a handy
companion. The Perl bindings follow the C API very closely, and the C reference
documentation should be considered the canonical source.

=head1 AUTHOR

Jeffrey Ratcliffe, E<lt>Jeffrey.Ratcliffe@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Jeffrey Ratcliffe

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
