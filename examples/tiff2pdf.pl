#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF ':all';
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Readonly;
Readonly my $T2P_COMPRESS_NONE => 0x00;
Readonly my $T2P_COMPRESS_G4   => 0x01;
Readonly my $T2P_COMPRESS_JPEG => 0x02;
Readonly my $T2P_COMPRESS_ZIP  => 0x04;

Readonly my $PS_UNIT_SIZE => 72;

Readonly my $EXIT_SUCCESS => 0;
Readonly my $EXIT_FAILURE => 1;

our $VERSION;

my ($optarg);
my $optind          = 0;
my $stoponerr       = 1;
my $TIFF2PDF_MODULE = "tiff2pdf";

sub main {
    my ( %t2p, $outfilename, $input );

    while ( my $c = getopt('o:q:u:x:y:w:l:r:p:e:c:a:t:s:k:jzndifbhF') ) {
        given ($c) {
            when ('a') {
                $t2p{pdf_author} = $optarg;
            }
            when ('b') {
                $t2p{pdf_image_interpolate} = 1;
            }
            when ('c') {
                $t2p{pdf_creator} = $optarg;
            }
            when ('d') {
                $t2p{pdf_defaultcompression} = $T2P_COMPRESS_NONE;
            }
            when ('e') {
                if ( not defined $optarg ) {
                    $t2p{pdf_datetime} = '';
                }
                else {
                    $t2p{pdf_datetime} = "D:$optarg";
                }
            }
            when ('F') {
                $t2p{pdf_image_fillpage} = 1;
            }
            when ('f') {
                $t2p{pdf_fitwindow} = 1;
            }
            when ('i') {
                $t2p{pdf_colorspace_invert} = 1;
            }
            when ('j') {
                $t2p{pdf_defaultcompression} = $T2P_COMPRESS_JPEG;
            }
            when ('k') {
                $t2p{pdf_keywords} = $optarg;
            }
            when ('l') {
                $t2p{pdf_overridepagesize}  = 1;
                $t2p{pdf_defaultpagelength} = $optarg * $PS_UNIT_SIZE /
                  ( $t2p{pdf_centimeters} ? 2.54 : 1 )
            }
            when ('n') {
                $t2p{pdf_nopassthrough} = 1;
            }
            when ('o') {
                $outfilename = $optarg;
            }
            when ('p') {
                if (
                    match_paper_size(
                        $t2p{pdf_defaultpagewidth},
                        $t2p{pdf_defaultpagelength},
                        $optarg
                    )
                  )
                {
                    $t2p{pdf_overridepagesize} = 1;
                }
                else {
                    warn
"$TIFF2PDF_MODULE: Unknown paper size $optarg, ignoring option\n";
                }
            }
            when ('q') {
                $t2p{pdf_defaultcompressionquality} = $optarg;
            }
            when ('r') {
                if ( substr( $optarg, 0, 1 ) eq 'o' ) {
                    $t2p{pdf_overrideres} = 1;
                }
            }
            when ('s') {
                $t2p{pdf_subject} = $optarg;
            }
            when ('t') {
                $t2p{pdf_title} = $optarg;
            }
            when ('u') {
                if ( substr( $optarg, 0, 1 ) eq 'm' ) {
                    $t2p{pdf_centimeters} = 1;
                }
            }
            when ('w') {
                $t2p{pdf_overridepagesize} = 1;
                $t2p{pdf_defaultpagewidth} = $optarg * $PS_UNIT_SIZE /
                  ( $t2p{pdf_centimeters} ? 2.54 : 1 )
            }
            when ('x') {
                $t2p{pdf_defaultxres} =
                  $optarg / ( $t2p{pdf_centimeters} ? 2.54 : 1 )
            }
            when ('y') {
                $t2p{pdf_defaultyres} =
                  $optarg / ( $t2p{pdf_centimeters} ? 2.54 : 1 )
            }
            when ('z') {
                $t2p{pdf_defaultcompression} = $T2P_COMPRESS_ZIP;
            }
            default {
                usage();
            }
        }
    }

    # Input
    if ( $optind < @ARGV ) {
        $input = Graphics::TIFF->Open( $ARGV[ $optind++ ], 'r' );
        if ( not defined $input ) {
            die
"$TIFF2PDF_MODULE: Unknown paper size $ARGV[$optind-1], ignoring option\n";
        }
    }
    else {
        warn "$TIFF2PDF_MODULE: No input file specified\n";
        usage();
        exit $EXIT_FAILURE;
    }
    if ( $optind < @ARGV ) {
        warn "$TIFF2PDF_MODULE: No support for multiple input files\n";
        usage();
        exit $EXIT_FAILURE;
    }

    # Output
    $t2p{outputdisable} = 0;
    if ( defined $outfilename ) {
        $t2p{outputfile} = fopen( $outfilename, "wb" );
        if ( not defined $t2p{outputfile} ) {
            die
"$TIFF2PDF_MODULE: Can't open output file $outfilename for writing\n";
        }
    }
    else {
        $outfilename = "-";
        $t2p{outputfile} = *STDOUT;
    }

    my $output = TIFFClientOpen(
        $outfilename,    "w",            \%t2p,           t2p_readproc(),
        t2p_writeproc(), t2p_seekproc(), t2p_closeproc(), t2p_sizeproc(),
        t2p_mapproc(),   t2p_unmapproc()
    );
    if ( not defined $output ) {
        die "$TIFF2PDF_MODULE: Can't initialize output descriptor\n";
    }

    # Validate
    t2p_validate( \%t2p );

    #    t2pSeekFile($output, 0, $SEEK_SET);

    # Write
    t2p_write_pdf( \%t2p, $input, $output );
    if ( $t2p{t2p_error} != 0 ) {
        die "$TIFF2PDF_MODULE: An error occurred creating output PDF file\n";
    }

    if ( defined $input )  { $input->Close }
    if ( defined $output ) { $output->Close }
    return $EXIT_SUCCESS;
}

sub getopt {
    my ($options) = @_;
    my $c;
    if ( substr( $ARGV[$optind], 0, 1 ) eq qw{-} ) {
        $c = substr $ARGV[ $optind++ ], 1, 1;
        my $regex = $c;
        if ( $regex eq qw{?} ) { $regex = qw{\?} }
        if ( $options =~ /$regex(:)?/xsm ) {
            if ( defined $1 ) { $optarg = $ARGV[ $optind++ ] }
        }
        else {
            warn "$TIFF2PDF_MODULE: invalid option -- $c\n";
            usage();
        }
    }
    return $c;
}

sub usage {
    warn Graphics::TIFF->GetVersion() . "\n\n";
    warn <<'EOS';
usage:  tiff2pdf [options] input.tiff
options:
 -o: output to file name
 -j: compress with JPEG
 -z: compress with Zip/Deflate
 -q: compression quality
 -n: no compressed data passthrough
 -d: do not compress (decompress)
 -i: invert colors
 -u: set distance unit, 'i' for inch, 'm' for centimeter
 -x: set x resolution default in dots per unit
 -y: set y resolution default in dots per unit
 -w: width in units
 -l: length in units
 -r: 'd' for resolution default, 'o' for resolution override
 -p: paper size, eg "letter", "legal", "A4"
 -F: make the tiff fill the PDF page
 -f: set PDF "Fit Window" user preference
 -e: date, overrides image or current date/time default, YYYYMMDDHHMMSS
 -c: sets document creator, overrides image software default
 -a: sets document author, overrides image artist default
 -t: sets document title, overrides image document name default
 -s: sets document subject, overrides image image description default
 -k: sets document keywords
 -b: set PDF "Interpolate" user preference
 -h: usage
EOS
    exit $EXIT_FAILURE;
}

exit main();
