#!/usr/bin/perl
use warnings;
use strict;
use Graphics::TIFF ':all';
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use Readonly;
Readonly my $PS_UNIT_SIZE => 72;

Readonly my $T2P_CS_BILEVEL  = 0x01;
Readonly my $T2P_CS_GRAY     = 0x02;
Readonly my $T2P_CS_RGB      = 0x04;
Readonly my $T2P_CS_CMYK     = 0x08;
Readonly my $T2P_CS_LAB      = 0x10;
Readonly my $T2P_CS_PALETTE  = 0x1000;
Readonly my $T2P_CS_CALGRAY  = 0x20;
Readonly my $T2P_CS_CALRGB   = 0x40;
Readonly my $T2P_CS_ICCBASED = 0x80;

Readonly my $T2P_COMPRESS_NONE => 0x00;
Readonly my $T2P_COMPRESS_G4   => 0x01;
Readonly my $T2P_COMPRESS_JPEG => 0x02;
Readonly my $T2P_COMPRESS_ZIP  => 0x04;

Readonly my $T2P_TRANSCODE_RAW    = 0x01;
Readonly my $T2P_TRANSCODE_ENCODE = 0x02;

Readonly my $T2P_SAMPLE_NOTHING                   = 0x0000;
Readonly my $T2P_SAMPLE_ABGR_TO_RGB               = 0x0001;
Readonly my $T2P_SAMPLE_RGBA_TO_RGB               = 0x0002;
Readonly my $T2P_SAMPLE_RGBAA_TO_RGB              = 0x0004;
Readonly my $T2P_SAMPLE_YCBCR_TO_RGB              = 0x0008;
Readonly my $T2P_SAMPLE_YCBCR_TO_LAB              = 0x0010;
Readonly my $T2P_SAMPLE_REALIZE_PALETTE           = 0x0020;
Readonly my $T2P_SAMPLE_SIGNED_TO_UNSIGNED        = 0x0040;
Readonly my $T2P_SAMPLE_LAB_SIGNED_TO_UNSIGNED    = 0x0040;
Readonly my $T2P_SAMPLE_PLANAR_SEPARATE_TO_CONTIG = 0x0100;

Readonly my $EXIT_SUCCESS => 0;
Readonly my $EXIT_FAILURE => 1;

Readonly my $T2P_ERR_OK    => 0;
Readonly my $T2P_ERR_ERROR => 1;

Readonly my $SEEK_SET => 0;    # Seek from beginning of file.
Readonly my $SEEK_CUR => 1;    # Seek from current position.

our $VERSION;

my ($optarg);
my $optind          = 0;
my $stoponerr       = 1;
my $TIFF2PDF_MODULE = "tiff2pdf";

sub main {
    my ( %t2p, $outfilename, $input );

    $t2p{pdf_majorversion}      = 1;
    $t2p{pdf_minorversion}      = 1;
    $t2p{pdf_defaultxres}       = 300.0;
    $t2p{pdf_defaultyres}       = 300.0;
    $t2p{pdf_defaultpagewidth}  = 612.0;
    $t2p{pdf_defaultpagelength} = 792.0;
    $t2p{pdf_xrefcount}         = 3;       # Catalog, Info, Pages

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
                if ( match_paper_size( \%t2p, $optarg ) ) {
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

    t2pSeekFile( $output, 0, $SEEK_SET );

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

sub match_paper_size {
    my ( $t2p, $papersize ) = @_;

    my @sizes = qw(
      LETTER A4 LEGAL
      EXECUTIVE LETTER LEGAL LEDGER TABLOID
      A B C D E F G H J K
      A10 A9 A8 A7 A6 A5 A4 A3 A2 A1 A0
      2A0 4A0 2A 4A
      B10 B9 B8 B7 B6 B5 B4 B3 B2 B1 B0
      JISB10 JISB9 JISB8 JISB7 JISB6 JISB5 JISB4
      JISB3 JISB2 JISB1 JISB0
      C10 C9 C8 C7 C6 C5 C4 C3 C2 C1 C0
      RA2 RA1 RA0 SRA4 SRA3 SRA2 SRA1 SRA0
      A3EXTRA A4EXTRA
      STATEMENT FOLIO QUARTO );
    my @widths = (
        612,  595,  612,  522,  612,  612,  792,  792,  612,  792,
        1224, 1584, 2448, 2016, 792,  2016, 2448, 2880, 74,   105,
        147,  210,  298,  420,  595,  842,  1191, 1684, 2384, 3370,
        4768, 3370, 4768, 88,   125,  176,  249,  354,  499,  709,
        1001, 1417, 2004, 2835, 91,   128,  181,  258,  363,  516,
        729,  1032, 1460, 2064, 2920, 79,   113,  162,  230,  323,
        459,  649,  918,  1298, 1298, 2599, 1219, 1729, 2438, 638,
        907,  1276, 1814, 2551, 914,  667,  396,  612,  609,
    );
    my @lengths = (
        792,  842,  1008, 756,  792,  1008,  1224,  1224,  792,  1224,
        1584, 2448, 3168, 2880, 6480, 10296, 12672, 10296, 105,  147,
        210,  298,  420,  595,  842,  1191,  1684,  2384,  3370, 4768,
        6741, 4768, 6741, 125,  176,  249,   354,   499,   709,  1001,
        1417, 2004, 2835, 4008, 128,  181,   258,   363,   516,  729,
        1032, 1460, 2064, 2920, 4127, 113,   162,   230,   323,  459,
        649,  918,  1298, 1837, 1837, 3677,  1729,  2438,  3458, 907,
        1276, 1814, 2551, 3628, 1262, 914,   612,   936,   780,
    );

    for my $i ( 0 .. @sizes ) {
        if ( $papersize eq $sizes[$i] ) {
            $t2p->{pdf_defaultpagewidth}  = $widths[$i];
            $t2p->{pdf_defaultpagelength} = $lengths[$i];
            return 1;
        }
    }
    return;
}

# This function validates the values of a T2P context struct pointer
# before calling t2p_write_pdf with it.

sub t2p_validate {
    my ($t2p) = @_;

    if ( $t2p->{pdf_defaultcompression} == $T2P_COMPRESS_JPEG ) {
        if (   $t2p->{pdf_defaultcompressionquality} > 100
            || $t2p->{pdf_defaultcompressionquality} < 1 )
        {
            $t2p->{pdf_defaultcompressionquality} = 0;
        }
    }
    elsif ( $t2p->{pdf_defaultcompression} == $T2P_COMPRESS_ZIP ) {
        my $m = $t2p->{pdf_defaultcompressionquality} % 100;
        if (   $t2p->{pdf_defaultcompressionquality} / 100 > 9
            || ( $m > 1 && $m < 10 )
            || $m > 15 )
        {
            $t2p->{pdf_defaultcompressionquality} = 0;
        }
        if ( $t2p->{pdf_defaultcompressionquality} % 100 != 0 ) {
            $t2p->{pdf_defaultcompressionquality} /= 100;
            $t2p->{pdf_defaultcompressionquality} *= 100;
            warn
"$TIFF2PDF_MODULE: PNG Group predictor differencing not implemented, assuming compression quality $t2p->{pdf_defaultcompressionquality}\n";
        }
        $t2p->{pdf_defaultcompressionquality} %= 100;
        if ( $t2p->{pdf_minorversion} < 2 ) { $t2p->{pdf_minorversion} = 2; }
    }
    return;
}

# This function scans the input TIFF file for pages.  It attempts
# to determine which IFD's of the TIFF file contain image document
# pages.  For each, it gathers some information that has to do
# with the output of the PDF document as a whole.

sub t2p_read_tiff_init {
    my ( $t2p, $input ) = @_;

    my $directorycount = $input->NumberOfDirectories();
    for my $i ( 0 .. $directorycount - 1 ) {
        my $subfiletype = 0;

        if ( !$input->SetDirectory($i) ) {
            my $msg =
              sprintf
              "%s: Can't allocate %lu bytes of memory for tiff_pages array, %s",
              $TIFF2PDF_MODULE, $i, $input->FileName;
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
        my ( $pagen, $paged ) = $input->GetField(TIFFTAG_PAGENUMBER);
        if ( defined $pagen and defined $paged ) {
            if ( ( $pagen > $paged ) && ( $paged != 0 ) ) {
                $t2p->{tiff_pages}[ $t2p->{tiff_pagecount} ]{page_number} =
                  $paged;
            }
            else {
                $t2p->{tiff_pages}[ $t2p->{tiff_pagecount} ]{page_number} =
                  $pagen;
            }
            goto ispage2;
        }
        if ( $subfiletype = $input->GetField(TIFFTAG_SUBFILETYPE) ) {
            if (   ( ( $subfiletype & FILETYPE_PAGE ) != 0 )
                || ( $subfiletype == 0 ) )
            {
                goto ispage;
            }
            else {
                goto isnotpage;
            }
        }
        if ( $subfiletype = $input->GetField(TIFFTAG_OSUBFILETYPE) ) {
            if (   ( $subfiletype == OFILETYPE_IMAGE )
                || ( $subfiletype == OFILETYPE_PAGE )
                || ( $subfiletype == 0 ) )
            {
                goto ispage;
            }
            else {
                goto isnotpage;
            }
        }
      ispage:
        $t2p->{tiff_pages}[ $t2p->{tiff_pagecount} ]{page_number} =
          $t2p->{tiff_pagecount};
      ispage2:
        $t2p->{tiff_pages}[ $t2p->{tiff_pagecount} ]{page_directory} = $i;
        if ( $input->IsTiled() ) {
            $t2p->{tiff_pages}[ $t2p->{tiff_pagecount} ]{page_tilecount} =
              $input->NumberOfTiles();
        }
        $t2p->{tiff_pagecount}++;
      isnotpage:
        0;
    }

    @{ $t2p->{tiff_pages} } =
      sort { $a->{page_number} <=> $b->{page_number} } @{ $t2p->{tiff_pages} };

    my $xuint16;
    for my $i ( 0 .. $t2p->{tiff_pagecount} - 1 ) {
        $t2p->{pdf_xrefcount} += 5;
        $input->SetDirectory( $t2p->{tiff_pages}[$i]{page_directory} );
        if (
            (
                $xuint16 =
                $input->GetField(TIFFTAG_PHOTOMETRIC)
                && ( $xuint16 == PHOTOMETRIC_PALETTE )
            )
            || ( $xuint16 = $input->GetField(TIFFTAG_INDEXED) )
          )
        {
            $t2p->{tiff_pages}[$i]{page_extra}++;
            $t2p->{pdf_xrefcount}++;
        }
        if ( $xuint16 = $input->GetField(TIFFTAG_COMPRESSION) ) {
            if (
                (
                       $xuint16 == COMPRESSION_DEFLATE
                    || $xuint16 == COMPRESSION_ADOBE_DEFLATE
                )
                && ( ( $t2p->{tiff_pages}[$i]{page_tilecount} != 0 )
                    || $input->NumberOfStrips() == 1 )
                && ( $t2p->{pdf_nopassthrough} == 0 )
              )
            {
                if ( $t2p->{pdf_minorversion} < 2 ) {
                    $t2p->{pdf_minorversion} = 2;
                }
            }
        }
        if ( @{ $t2p->{tiff_transferfunction} } =
            $input->GetField(TIFFTAG_TRANSFERFUNCTION) )
        {
            if ( $t2p->{tiff_transferfunction}[1] !=
                $t2p->{tiff_transferfunction}[0] )
            {
                $t2p->{tiff_transferfunctioncount} = 3;
                $t2p->{tiff_pages}[$i]{page_extra} += 4;
                $t2p->{pdf_xrefcount} += 4;
            }
            else {
                $t2p->{tiff_transferfunctioncount} = 1;
                $t2p->{tiff_pages}[$i]{page_extra} += 2;
                $t2p->{pdf_xrefcount} += 2;
            }
            if ( $t2p->{pdf_minorversion} < 2 ) {
                $t2p->{pdf_minorversion} = 2;
            }
        }
        else {
            $t2p->{tiff_transferfunctioncount} = 0;
        }
        if ( $t2p->{tiff_iccprofile} = $input->GetField(TIFFTAG_ICCPROFILE) ) {
            $t2p->{tiff_pages}[$i]{page_extra}++;
            $t2p->{pdf_xrefcount}++;
            if ( $t2p->{pdf_minorversion} < 3 ) { $t2p->{pdf_minorversion} = 3 }
        }
        $t2p->{tiff_tiles}[$i]{tiles_tilecount} =
          $t2p->{tiff_pages}[$i]{page_tilecount};
        if (   ( $xuint16 = $input->GetField(TIFFTAG_PLANARCONFIG) != 0 )
            && ( $xuint16 == PLANARCONFIG_SEPARATE ) )
        {
            $xuint16 = $input->GetField(TIFFTAG_SAMPLESPERPIXEL);
            $t2p->{tiff_tiles}[$i]{tiles_tilecount} /= $xuint16;
        }
        if ( $t2p->{tiff_tiles}[$i]{tiles_tilecount} > 0 ) {
            $t2p->{pdf_xrefcount} +=
              ( $t2p->{tiff_tiles}[$i]{tiles_tilecount} - 1 ) * 2;
            $t2p->{tiff_tiles}[$i]{tiles_tilewidth} =
              $input->GetField(TIFFTAG_TILEWIDTH);
            $t2p->{tiff_tiles}[$i]{tiles_tilelength} = $input =
              GetField(TIFFTAG_TILELENGTH);
        }
    }

    return;
}

# This function sets the input directory to the directory of a given
# page and determines information about the image.  It checks
# the image characteristics to determine if it is possible to convert
# the image data into a page of PDF output, setting values of the T2P
# struct for this page.  It determines what color space is used in
# the output PDF to represent the image.

# It determines if the image can be converted as raw data without
# requiring transcoding of the image data.

sub t2p_read_tiff_data {
    my ( $t2p, $input ) = @_;

    $t2p->{pdf_transcode}    = $T2P_TRANSCODE_ENCODE;
    $t2p->{pdf_sample}       = $T2P_SAMPLE_NOTHING;
    $t2p->{pdf_switchdecode} = $t2p->{pdf_colorspace_invert};

    $input->SetDirectory(
        $t2p->{tiff_pages}[ $t2p->{pdf_page} ]{page_directory} );

    $t2p->{tiff_width} = $input->GetField(TIFFTAG_IMAGEWIDTH);
    if ( $t2p->{tiff_width} == 0 ) {
        my $msg = sprintf "$TIFF2PDF_MODULE: No support for %s with zero width",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }

    $t2p->{tiff_length} = $input->GetField(TIFFTAG_IMAGELENGTH);
    if ( $t2p->{tiff_length} == 0 ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: No support for %s with zero length",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }

    if ( $t2p->{tiff_compression} = $input->GetField(TIFFTAG_COMPRESSION) == 0 )
    {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: No support for %s with no compression tag",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }
    if ( TIFFIsCODECConfigured( $t2p->{tiff_compression} ) == 0 ) {
        my $msg =
          sprintf
"$TIFF2PDF_MODULE: No support for %s with compression type %u:  not configured",
          $input->FileName(), $t2p->{tiff_compression};
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }

    $t2p->{tiff_bitspersample} =
      $input->GetFieldDefaulted(TIFFTAG_BITSPERSAMPLE);
    given ( $t2p->{tiff_bitspersample} ) {
        when (1) { }
        when (2) { }
        when (4) { }
        when (8) { }
        when (0) {
            my $msg =
              sprintf
              "$TIFF2PDF_MODULE: Image %s has 0 bits per sample, assuming 1",
              $input->FileName();
            warn "$msg\n";
            $t2p->{tiff_bitspersample} = 1;
        }
        default {
            my $msg =
              sprintf
              "$TIFF2PDF_MODULE: No support for %s with %u bits per sample",
              $input->FileName(), $t2p->{tiff_bitspersample};
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
    }

    $t2p->{tiff_samplesperpixel} =
      $input->GetFieldDefaulted(TIFFTAG_SAMPLESPERPIXEL);
    if ( $t2p->{tiff_samplesperpixel} > 4 ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: No support for %s with %u samples per pixel",
          $input->FileName(), $t2p->{tiff_samplesperpixel};
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }
    if ( $t2p->{tiff_samplesperpixel} == 0 ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Image %s has 0 samples per pixel, assuming 1",
          $input->FileName();
        warn "$msg\n";
        $t2p->{tiff_samplesperpixel} = 1;
    }

    my $xuint16 = $input->GetField(TIFFTAG_SAMPLEFORMAT);
    if ( $xuint16 != 0 and $xuint16 != 1 and $xuint16 != 4 ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: No support for %s with sample format %u",
          $input->FileName(), $xuint16;
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }

    $t2p->{tiff_fillorder} = $input->GetFieldDefaulted(TIFFTAG_FILLORDER);

    if ( $t2p->{tiff_photometric} =
        $input->TIFFGetField(TIFFTAG_PHOTOMETRIC) == 0 )
    {
        my $msg =
          sprintf
"$TIFF2PDF_MODULE: No support for %s with no photometric interpretation tag",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return;
    }

    given ( $t2p->{tiff_photometric} ) {
        when ( PHOTOMETRIC_MINISWHITE | PHOTOMETRIC_MINISBLACK ) {
            if ( $t2p->{tiff_bitspersample} == 1 ) {
                $t2p->{pdf_colorspace} = $T2P_CS_BILEVEL;
                if ( $t2p->{tiff_photometric} == PHOTOMETRIC_MINISWHITE ) {
                    $t2p->{pdf_switchdecode} ^= 1;
                }
            }
            else {
                $t2p->{pdf_colorspace} = $T2P_CS_GRAY;
                if ( $t2p->{tiff_photometric} == PHOTOMETRIC_MINISWHITE ) {
                    $t2p->{pdf_switchdecode} ^= 1;
                }
            }
        }
        when (PHOTOMETRIC_RGB) {
            $t2p->{pdf_colorspace} = $T2P_CS_RGB;
            if ( $t2p->{tiff_samplesperpixel} == 3 ) {
                break;
            }
            if ( $xuint16 = $input->GetField(TIFFTAG_INDEXED) ) {
                if ( $xuint16 == 1 ) { goto photometric_palette }
            }
            if ( $t2p->{tiff_samplesperpixel} > 3 ) {
                if ( $t2p->{tiff_samplesperpixel} == 4 ) {
                    $t2p->{pdf_colorspace} = $T2P_CS_RGB;
                    my @extra = $input->TIFFGetField(TIFFTAG_EXTRASAMPLES);
                    if ( @extra and $extra[0] == 1 ) {
                        if ( $extra[1] == EXTRASAMPLE_ASSOCALPHA ) {
                            $t2p->{pdf_sample} = $T2P_SAMPLE_RGBAA_TO_RGB;
                            break;
                        }
                        if ( $extra[1] == EXTRASAMPLE_UNASSALPHA ) {
                            $t2p->{pdf_sample} = $T2P_SAMPLE_RGBA_TO_RGB;
                            break;
                        }
                        my $msg =
                          sprintf
"$TIFF2PDF_MODULE: RGB image %s has 4 samples per pixel, assuming RGBA",
                          $input->FileName();
                        warn "$msg\n";
                        break;
                    }
                    $t2p->{pdf_colorspace} = $T2P_CS_CMYK;
                    $t2p->{pdf_switchdecode} ^= 1;
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: RGB image %s has 4 samples per pixel, assuming inverse CMYK",
                      $input->FileName();
                    warn "$msg\n";
                    break;
                }
                else {
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: No support for RGB image %s with %u samples per pixel",
                      $input->FileName(), $t2p->{tiff_samplesperpixel};
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    break;
                }
            }
            else {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for RGB image %s with %u samples per pixel",
                  $input->FileName(), $t2p->{tiff_samplesperpixel};
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                break;
            }
        }
        when (PHOTOMETRIC_PALETTE) {
          photometric_palette:
            if ( $t2p->{tiff_samplesperpixel} != 1 ) {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for palettized image %s with not one sample per pixel",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
            $t2p->{pdf_colorspace}  = $T2P_CS_RGB | $T2P_CS_PALETTE;
            $t2p->{pdf_palettesize} = 0x0001 << $t2p->{tiff_bitspersample};
            my @rgb = $input->GetField(TIFFTAG_COLORMAP);
            if ( !@rgb ) {
                my $msg =
                  sprintf
                  "$TIFF2PDF_MODULE: Palettized image %s has no color map",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
            for my $i ( 0 .. $t2p->{pdf_palettesize} - 1 ) {
                $t2p->{pdf_palette}[ $i * 3 ]     = $rgb[0][$i] >> 8;
                $t2p->{pdf_palette}[ $i * 3 + 1 ] = $rgb[1][$i] >> 8;
                $t2p->{pdf_palette}[ $i * 3 + 2 ] = $rgb[2][$i] >> 8;
            }
            $t2p->{pdf_palettesize} *= 3;
            break;
        }
        when (PHOTOMETRIC_SEPARATED) {
            if ( $xuint16 = $input->GetField(TIFFTAG_INDEXED) ) {
                if ( $xuint16 == 1 ) { goto photometric_palette_cmyk }
            }
            if ( $xuint16 = $input->TIFFGetField(TIFFTAG_INKSET) ) {
                if ( $xuint16 != INKSET_CMYK ) {
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: No support for %s because its inkset is not CMYK",
                      $input->FileName();
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    return;
                }
            }
            if ( $t2p->{tiff_samplesperpixel} == 4 ) {
                $t2p->{pdf_colorspace} = $T2P_CS_CMYK;
            }
            else {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for %s because it has %u samples per pixel",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
            break;
          photometric_palette_cmyk:
            if ( $t2p->{tiff_samplesperpixel} != 1 ) {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for palettized CMYK image %s with not one sample per pixel",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
            $t2p->{pdf_colorspace}  = $T2P_CS_CMYK | $T2P_CS_PALETTE;
            $t2p->{pdf_palettesize} = 0x0001 << $t2p->{tiff_bitspersample};
            my @rgba = $input->TIFFGetField( TIFFTAG_COLORMAP, &r, &g, &b, &a );
            if ( !@rgba ) {
                my $msg =
                  sprintf
                  "$TIFF2PDF_MODULE: Palettized image %s has no color map",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
            for my $i ( 0 .. $t2p->{pdf_palettesize} - 1 ) {
                $t2p->{pdf_palette}[ $i * 4 ]     = $rgba[0][$i] >> 8;
                $t2p->{pdf_palette}[ $i * 4 + 1 ] = $rgba[1][$i] >> 8;
                $t2p->{pdf_palette}[ $i * 4 + 2 ] = $rgba[2][$i] >> 8;
                $t2p->{pdf_palette}[ $i * 4 + 3 ] = $rgba[3][$i] >> 8;
            }
            $t2p->{pdf_palettesize} *= 4;
        }
        when (PHOTOMETRIC_YCBCR) {
            $t2p->{pdf_colorspace} = $T2P_CS_RGB;
            if ( $t2p->{tiff_samplesperpixel} == 1 ) {
                $t2p->{pdf_colorspace}   = $T2P_CS_GRAY;
                $t2p->{tiff_photometric} = PHOTOMETRIC_MINISBLACK;
                break;
            }
            $t2p->{pdf_sample} = $T2P_SAMPLE_YCBCR_TO_RGB;
            if ( $t2p->{pdf_defaultcompression} == $T2P_COMPRESS_JPEG ) {
                $t2p->{pdf_sample} = $T2P_SAMPLE_NOTHING;
            }
        }
        when (PHOTOMETRIC_CIELAB) {
            $t2p->{pdf_labrange}[0] = -127;
            $t2p->{pdf_labrange}[1] = 127;
            $t2p->{pdf_labrange}[2] = -127;
            $t2p->{pdf_labrange}[3] = 127;
            $t2p->{pdf_sample}      = $T2P_SAMPLE_LAB_SIGNED_TO_UNSIGNED;
            $t2p->{pdf_colorspace}  = $T2P_CS_LAB;
        }
        when (PHOTOMETRIC_ICCLAB) {
            $t2p->{pdf_labrange}[0] = 0;
            $t2p->{pdf_labrange}[1] = 255;
            $t2p->{pdf_labrange}[2] = 0;
            $t2p->{pdf_labrange}[3] = 255;
            $t2p->{pdf_colorspace}  = $T2P_CS_LAB;
        }
        when (PHOTOMETRIC_ITULAB) {
            $t2p->{pdf_labrange}[0] = -85;
            $t2p->{pdf_labrange}[1] = 85;
            $t2p->{pdf_labrange}[2] = -75;
            $t2p->{pdf_labrange}[3] = 124;
            $t2p->{pdf_sample}      = $T2P_SAMPLE_LAB_SIGNED_TO_UNSIGNED;
            $t2p->{pdf_colorspace}  = $T2P_CS_LAB;
        }
        when (PHOTOMETRIC_LOGL) { }
        when (PHOTOMETRIC_LOGLUV) {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: No support for %s with photometric interpretation LogL/LogLuv",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
        default {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: No support for %s with photometric interpretation %u",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
    }
    if ( $t2p->{tiff_planar} = $input->GetField(TIFFTAG_PLANARCONFIG) ) {
        given ( $t2p->{tiff_planar} ) {
            when (0) {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: Image %s has planar configuration 0, assuming 1",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{tiff_planar} = PLANARCONFIG_CONTIG;
            }
            when (PLANARCONFIG_CONTIG) { }
            when (PLANARCONFIG_SEPARATE) {
                $t2p->{pdf_sample} = $T2P_SAMPLE_PLANAR_SEPARATE_TO_CONTIG;
                if ( $t2p->{tiff_bitspersample} != 8 ) {
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: No support for %s with separated planar configuration and %u bits per sample",
                      $input->FileName(), $t2p->{tiff_bitspersample};
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    return;
                }
            }
            default {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for %s with planar configuration %u",
                  $input->FileName(), $t2p->{tiff_planar};
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return;
            }
        }
    }

    $t2p->{tiff_orientation} = $input->GetFieldDefaulted(TIFFTAG_ORIENTATION);
    if ( $t2p->{tiff_orientation} > 8 ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: Image %s has orientation %u, assuming 0",
          $input->FileName(), $t2p->{tiff_orientation};
        warn "$msg\n";
        $t2p->{tiff_orientation} = 0;
    }

    if ( $t2p->{tiff_xres} = $input->GetField(TIFFTAG_XRESOLUTION) == 0 ) {
        $t2p->{tiff_xres} = 0.0;
    }
    if ( $t2p->{tiff_yres} = $input->GetField(TIFFTAG_YRESOLUTION) == 0 ) {
        $t2p->{tiff_yres} = 0.0;
    }
    $t2p->{tiff_resunit} = $input->GetFieldDefaulted(TIFFTAG_RESOLUTIONUNIT);
    if ( $t2p->{tiff_resunit} == RESUNIT_CENTIMETER ) {
        $t2p->{tiff_xres} *= 2.54;
        $t2p->{tiff_yres} *= 2.54;
    }
    elsif ($t2p->{tiff_resunit} != RESUNIT_INCH
        && $t2p->{pdf_centimeters} != 0 )
    {
        $t2p->{tiff_xres} *= 2.54;
        $t2p->{tiff_yres} *= 2.54;
    }

    t2p_compose_pdf_page($t2p);

    $t2p->{pdf_transcode} = $T2P_TRANSCODE_ENCODE;
    if ( $t2p->{pdf_nopassthrough} == 0 ) {
        if ( $t2p->{tiff_compression} == COMPRESSION_CCITTFAX4 ) {
            if ( $input->IsTiled() || ( $input->NumberOfStrips() == 1 ) ) {
                $t2p->{pdf_transcode}   = $T2P_TRANSCODE_RAW;
                $t2p->{pdf_compression} = $T2P_COMPRESS_G4;
            }
        }
        if (   $t2p->{tiff_compression} == COMPRESSION_ADOBE_DEFLATE
            || $t2p->{tiff_compression} == COMPRESSION_DEFLATE )
        {
            if ( $input->IsTiled() || ( $input->NumberOfStrips() == 1 ) ) {
                $t2p->{pdf_transcode}   = $T2P_TRANSCODE_RAW;
                $t2p->{pdf_compression} = $T2P_COMPRESS_ZIP;
            }
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_OJPEG ) {
            $t2p->{pdf_transcode}   = $T2P_TRANSCODE_RAW;
            $t2p->{pdf_compression} = $T2P_COMPRESS_JPEG;
            t2p_process_ojpeg_tables( $t2p, $input );
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_JPEG ) {
            $t2p->{pdf_transcode}   = $T2P_TRANSCODE_RAW;
            $t2p->{pdf_compression} = $T2P_COMPRESS_JPEG;
        }
    }

    if ( $t2p->{pdf_transcode} != $T2P_TRANSCODE_RAW ) {
        $t2p->{pdf_compression} = $t2p->{pdf_defaultcompression};
    }

    if ( $t2p->{pdf_defaultcompression} == $T2P_COMPRESS_JPEG ) {
        if ( $t2p->{pdf_colorspace} & $T2P_CS_PALETTE ) {
            $t2p->{pdf_sample} |= $T2P_SAMPLE_REALIZE_PALETTE;
            $t2p->{pdf_colorspace} ^= $T2P_CS_PALETTE;
            $t2p->{tiff_pages}[ $t2p->{pdf_page} ]{page_extra}--;
        }
    }
    if ( $t2p->{tiff_compression} == COMPRESSION_JPEG ) {
        if ( $t2p->{tiff_planar} == PLANARCONFIG_SEPARATE ) {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: No support for %s with JPEG compression and separated planar configuration",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
    }
    if ( $t2p->{tiff_compression} == COMPRESSION_OJPEG ) {
        if ( $t2p->{tiff_planar} == PLANARCONFIG_SEPARATE ) {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: No support for %s with OJPEG compression and separated planar configuration",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return;
        }
    }

    if ( $t2p->{pdf_sample} & $T2P_SAMPLE_REALIZE_PALETTE ) {
        if ( $t2p->{pdf_colorspace} & $T2P_CS_CMYK ) {
            $t2p->{tiff_samplesperpixel} = 4;
            $t2p->{tiff_photometric}     = PHOTOMETRIC_SEPARATED;
        }
        else {
            $t2p->{tiff_samplesperpixel} = 3;
            $t2p->{tiff_photometric}     = PHOTOMETRIC_RGB;
        }
    }

    if ( $t2p->{tiff_transferfunction} =
        $input->GetField(TIFFTAG_TRANSFERFUNCTION) )
    {
        if ( $t2p->{tiff_transferfunction}[1] !=
            $t2p->{tiff_transferfunction}[0] )
        {
            $t2p->{tiff_transferfunctioncount} = 3;
        }
        else {
            $t2p->{tiff_transferfunctioncount} = 1;
        }
    }
    else {
        $t2p->{tiff_transferfunctioncount} = 0;
    }
    my @xfloat = $input->GetField(TIFFTAG_WHITEPOINT);
    if (@xfloat) {
        $t2p->{tiff_whitechromaticities} = @xfloat;
        if ( $t2p->{pdf_colorspace} & $T2P_CS_GRAY ) {
            $t2p->{pdf_colorspace} |= $T2P_CS_CALGRAY;
        }
        if ( $t2p->{pdf_colorspace} & $T2P_CS_RGB ) {
            $t2p->{pdf_colorspace} |= $T2P_CS_CALRGB;
        }
    }
    if ( @xfloat = $input->GetField(TIFFTAG_PRIMARYCHROMATICITIES) ) {
        $t2p->{tiff_primarychromaticities} = @xfloat;
        if ( $t2p->{pdf_colorspace} & $T2P_CS_RGB ) {
            $t2p->{pdf_colorspace} |= $T2P_CS_CALRGB;
        }
    }
    if ( $t2p->{pdf_colorspace} & $T2P_CS_LAB ) {
        if ( @xfloat = $input->GetField( TIFFTAG_WHITEPOINT, &xfloatp ) ) {
            $t2p->{tiff_whitechromaticities} = @xfloat;
        }
        else {
            $t2p->{tiff_whitechromaticities}[0] = 0.3457;
            $t2p->{tiff_whitechromaticities}[1] = 0.3585;
        }
    }
    if ( ( $t2p->{tiff_iccprofilelength}, $t2p->{tiff_iccprofile} ) =
        $input->TIFFGetField(TIFFTAG_ICCPROFILE) )
    {
        $t2p->{pdf_colorspace} |= $T2P_CS_ICCBASED;
    }
    else {
        $t2p->{tiff_iccprofilelength} = 0;
        $t2p->{tiff_iccprofile}       = undef;
    }

    if ( $t2p->{tiff_bitspersample} == 1 && $t2p->{tiff_samplesperpixel} == 1 )
    {
        $t2p->{pdf_compression} = $T2P_COMPRESS_G4;
    }
    return;
}

# Returns a non-zero value when the tile is on the right edge
# and does not have full imaged tile width.

sub t2p_tile_is_right_edge {
    my ( $tiles, $tile ) = @_;

    if (   ( ( $tile + 1 ) % $tiles->{tiles_tilecountx} == 0 )
        && ( $tiles->{tiles_edgetilewidth} != 0 ) )
    {
        return 1;
    }
    return 0;
}

# Returns a non-zero value when the tile is on the bottom edge
# and does not have full imaged tile length.

sub t2p_tile_is_bottom_edge {
    my ( $tiles, $tile ) = @_;

    if (
        (
            ( $tile + 1 ) >
            ( $tiles->{tiles_tilecount} - $tiles->{tiles_tilecountx} )
        )
        && ( $tiles->{tiles_edgetilelength} != 0 )
      )
    {
        return 1;
    }
    return 0;
}

# Returns a non-zero value when the tile is a right edge tile
# or a bottom edge tile.

sub t2p_tile_is_edge {
    my ( $tiles, $tile ) = @_;

    return t2p_tile_is_right_edge( $tiles, $tile ) |
      t2p_tile_is_bottom_edge( $tiles, $tile );
}

# Returns a non-zero value when the tile is a right edge tile and a bottom
# edge tile.

sub t2p_tile_is_corner_edge {
    my ( $tiles, $tile ) = @_;

    return t2p_tile_is_right_edge( $tiles, $tile ) &
      t2p_tile_is_bottom_edge( $tiles, $tile );
}

# Reads the raster image data from the input TIFF for an image and writes
# the data to the output PDF XObject image dictionary stream.  It returns the amount written
# or zero on error.

sub t2p_readwrite_pdf_image {
    my ( $t2p, $input, $output ) = @_;

    my $written         = 0;
    my $buffer          = 0;
    my $samplebuffer    = 0;
    my $read            = 0;
    my $i               = 0;
    my $j               = 0;
    my $stripcount      = 0;
    my $stripsize       = 0;
    my $sepstripcount   = 0;
    my $sepstripsize    = 0;
    my $inputoffset     = 0;
    my $h_samp          = 1;
    my $v_samp          = 1;
    my $ri              = 1;
    my $rows            = 0;
    my $striplength     = 0;
    my $max_striplength = 0;

    # Fail if prior error (in particular, can't trust tiff_datasize)
    if ( $t2p->{t2p_error} != $T2P_ERR_OK ) { return 0 }

    if ( $t2p->{pdf_transcode} == $T2P_TRANSCODE_RAW ) {
        if ( $t2p->{pdf_compression} == $T2P_COMPRESS_G4 ) {
            $buffer = $input->ReadRawStrip( 0, $t2p->{tiff_datasize} );
            if ( $t2p->{tiff_fillorder} == FILLORDER_LSB2MSB ) {

                # make sure is lsb-to-msb
                # bit-endianness fill order
                TIFFReverseBits( $buffer, $t2p->{tiff_datasize} );
            }
            t2pWriteFile( $output, $buffer, $t2p->{tiff_datasize} );
            return $t2p->{tiff_datasize};
        }
        if ( $t2p->{pdf_compression} == $T2P_COMPRESS_ZIP ) {
            $buffer = $input->ReadRawStrip( 0, $t2p->{tiff_datasize} );
            if ( $t2p->{tiff_fillorder} == FILLORDER_LSB2MSB ) {
                TIFFReverseBits( $buffer, $t2p->{tiff_datasize} );
            }
            t2pWriteFile( $output, $buffer, $t2p->{tiff_datasize} );
            return $t2p->{tiff_datasize};
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_OJPEG ) {

            if ( $t2p->{tiff_dataoffset} != 0 ) {
                if ( $t2p->{pdf_ojpegiflength} == 0 ) {
                    $inputoffset = t2pSeekFile( $input, 0, $SEEK_CUR );
                    t2pSeekFile( $input, $t2p->{tiff_dataoffset}, $SEEK_SET );
                    t2pReadFile( $input, $buffer, $t2p->{tiff_datasize} );
                    t2pSeekFile( $input, $inputoffset, $SEEK_SET );
                    t2pWriteFile( $output, $buffer, $t2p->{tiff_datasize} );
                    return $t2p->{tiff_datasize};
                }
                else {
                    $inputoffset = t2pSeekFile( $input, 0, $SEEK_CUR );
                    t2pSeekFile( $input, $t2p->{tiff_dataoffset}, $SEEK_SET );
                    $buffer = t2pReadFile( $input, $t2p->{pdf_ojpegiflength} );
                    $t2p->{pdf_ojpegiflength} = 0;
                    t2pSeekFile( $input, $inputoffset, $SEEK_SET );
                    ( $h_samp, $v_samp ) =
                      $input->TIFFGetField(TIFFTAG_YCBCRSUBSAMPLING);
                    $buffer .= 0xff;
                    $buffer .= 0xdd;
                    $buffer .= 0x00;
                    $buffer .= 0x04;
                    $h_samp *= 8;
                    $v_samp *= 8;
                    $ri = ( $t2p->{tiff_width} + $h_samp - 1 ) / $h_samp;
                    $rows->$input->TIFFGetField(TIFFTAG_ROWSPERSTRIP);
                    $ri *= ( $rows + $v_samp - 1 ) / $v_samp;
                    $buffer .= ( $ri >> 8 ) & 0xff;
                    $buffer .= $ri & 0xff;
                    $stripcount = $input->NumberOfStrips();

                    for my $i ( 0 .. $stripcount - 1 ) {
                        if ( $i != 0 ) {
                            $buffer .= 0xff;
                            $buffer .= ( 0xd0 | ( ( $i - 1 ) % 8 ) );
                        }
                        $buffer .= $input->ReadRawStrip( $i, -1 );
                    }
                    t2pWriteFile( $output, $buffer, length($buffer) );
                    return length($buffer);
                }
            }
            else {
                if ( !$t2p->{pdf_ojpegdata} ) {
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: No support for OJPEG image %s with bad tables",
                      $input->FileName();
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    return 0;
                }
                _TIFFmemcpy( $buffer, $t2p->{pdf_ojpegdata},
                    $t2p->{pdf_ojpegdatalength} );
                $stripcount = $input->NumberOfStrips();
                for my $i ( 0 .. $stripcount - 1 ) {
                    if ( $i != 0 ) {
                        $buffer .= 0xff;
                        $buffer .= ( 0xd0 | ( ( $i - 1 ) % 8 ) );
                    }
                    $buffer .= $input->ReadRawStrip( $i, -1 );
                }
                if (   substr( $buffer, length($buffer), 1 ) != 0xd9
                    or substr( $buffer, length($buffer) - 1, 1 ) != 0xff )
                {
                    $buffer .= 0xff;
                    $buffer .= 0xd9;
                }
                t2pWriteFile( $output, $buffer, length($buffer) );
                return length($buffer);
            }
            return $t2p->{tiff_datasize};
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_JPEG ) {
            if ( my ( $count, $jpt ) =
                $input->GetField(TIFFTAG_JPEGTABLES) != 0 )
            {
                if ( $count > 4 ) {
                    _TIFFmemcpy( $buffer, $jpt, $count );
                }
            }
            $stripcount = $input->NumberOfStrips();
            my @sbc = $input->GetField(TIFFTAG_STRIPBYTECOUNTS);
            for my $i ( 0 .. $stripcount - 1 ) {
                if ( $sbc[$i] > $max_striplength ) {
                    $max_striplength = $sbc[$i];
                }
            }
            for my $i ( 0 .. $stripcount - 1 ) {
                my $stripbuffer = $input->ReadRawStrip( $i, -1 );
                if (
                    !t2p_process_jpeg_strip(
                        $stripbuffer, length($stripbuffer),
                        $buffer,      length($buffer),
                        $i,           $t2p->{tiff_length}
                    )
                  )
                {
                    my $msg =
                      sprintf
"$TIFF2PDF_MODULE: Can't process JPEG data in input file %s",
                      $input->FileName();
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    return 0;
                }
            }
            $buffer .= 0xff;
            $buffer .= 0xd9;
            t2pWriteFile( $output, $buffer, length($buffer) );
            return length($buffer);
        }
        0;
    }

    if ( $t2p->{pdf_sample} == $T2P_SAMPLE_NOTHING ) {
        $stripsize  = $input->StripSize();
        $stripcount = $input->TIFFNumberOfStrips();
        for my $i ( 0 .. $stripcount - 1 ) {
            my $stripbuffer = $input->ReadEncodedStrip( $i, $stripsize );
            if ( length($stripbuffer) == 0 ) {
                my $msg =
                  sprintf "$TIFF2PDF_MODULE: Error on decoding strip %u of %s",
                  $i, $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
            $buffer .= $stripbuffer;
        }
    }
    else {
        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_PLANAR_SEPARATE_TO_CONTIG ) {

            $sepstripsize  = $input->StripSize();
            $sepstripcount = $input->NumberOfStrips();

            $stripsize  = $sepstripsize * $t2p->{tiff_samplesperpixel};
            $stripcount = $sepstripcount / $t2p->{tiff_samplesperpixel};

            for my $i ( 0 .. $stripcount - 1 ) {
                for my $j ( 0 .. $t2p->{tiff_samplesperpixel} - 1 ) {
                    my $stripbuffer =
                      $input->ReadEncodedStrip( $i + $j * $stripcount,
                        $sepstripsize );
                    if ( length($stripbuffer) == 0 ) {
                        my $msg =
                          sprintf
                          "$TIFF2PDF_MODULE: Error on decoding strip %u of %s",
                          $i + $j * $stripcount, $input->FileName();
                        warn "$msg\n";
                        $t2p->{t2p_error} = $T2P_ERR_ERROR;
                        return 0;
                    }
                    $buffer .= $stripbuffer;
                }
                $buffer .=
                  t2p_sample_planar_separate_to_contig( $t2p, $samplebuffer,
                    length $samplebuffer );
            }
            goto dataready;
        }

        $stripsize  = $input->StripSize();
        $stripcount = $input->NumberOfStrips();
        for my $i ( 0 .. $stripcount - 1 ) {
            my $stripbuffer = $input->ReadEncodedStrip( $i, $stripsize );
            if ( length($stripbuffer) == 0 ) {
                my $msg =
                  sprintf "$TIFF2PDF_MODULE: Error on decoding strip %u of %s",
                  $i, $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
            $buffer .= $stripbuffer;
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_REALIZE_PALETTE ) {

            # FIXME: overflow?
            $buffer = $samplebuffer;
            $t2p->{tiff_datasize} *= $t2p->{tiff_samplesperpixel};
            t2p_sample_realize_palette( $t2p, $buffer );
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_RGBA_TO_RGB ) {
            $t2p->{tiff_datasize} = t2p_sample_rgba_to_rgb( $buffer,
                $t2p->{tiff_width} * $t2p->{tiff_length} );
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_RGBAA_TO_RGB ) {
            $t2p->{tiff_datasize} = t2p_sample_rgbaa_to_rgb( $buffer,
                $t2p->{tiff_width} * $t2p->{tiff_length} );
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_YCBCR_TO_RGB ) {
            $buffer =
              $input->ReadRGBAImageOriented( $t2p->{tiff_width},
                $t2p->{tiff_length}, ORIENTATION_TOPLEFT, 0 );
            if ( !$buffer ) {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: Can't use TIFFReadRGBAImageOriented to extract RGB image from %s",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
            $t2p->{tiff_datasize} = t2p_sample_abgr_to_rgb( $buffer,
                $t2p->{tiff_width} * $t2p->{tiff_length} );

        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_LAB_SIGNED_TO_UNSIGNED ) {
            $t2p->{tiff_datasize} = t2p_sample_lab_signed_to_unsigned( $buffer,
                $t2p->{tiff_width} * $t2p->{tiff_length} );
        }
    }

  dataready:

    t2p_disable($output);
    $output->SetField( TIFFTAG_PHOTOMETRIC,     $t2p->{tiff_photometric} );
    $output->SetField( TIFFTAG_BITSPERSAMPLE,   $t2p->{tiff_bitspersample} );
    $output->SetField( TIFFTAG_SAMPLESPERPIXEL, $t2p->{tiff_samplesperpixel} );
    $output->SetField( TIFFTAG_IMAGEWIDTH,      $t2p->{tiff_width} );
    $output->SetField( TIFFTAG_IMAGELENGTH,     $t2p->{tiff_length} );
    $output->SetField( TIFFTAG_ROWSPERSTRIP,    $t2p->{tiff_length} );
    $output->SetField( TIFFTAG_PLANARCONFIG,    PLANARCONFIG_CONTIG );
    $output->SetField( TIFFTAG_FILLORDER,       FILLORDER_MSB2LSB );

    given ( $t2p->{pdf_compression} ) {
        when ($T2P_COMPRESS_NONE) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_NONE );
        }
        when ($T2P_COMPRESS_G4) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_CCITTFAX4 );
        }
        when ($T2P_COMPRESS_JPEG) {
            if ( $t2p->{tiff_photometric} == PHOTOMETRIC_YCBCR ) {
                my ( $hor, $ver ) = ( 0, 0 );
                if ( ( $hor, $ver ) =
                    $input->GetField(TIFFTAG_YCBCRSUBSAMPLING) != 0 )
                {
                    if ( $hor != 0 && $ver != 0 ) {
                        $output->SetField( TIFFTAG_YCBCRSUBSAMPLING, $hor,
                            $ver );
                    }
                }
                my $xfloatp = $input->TIFFGetField(TIFFTAG_REFERENCEBLACKWHITE);
                if ( $xfloatp != 0 ) {
                    $output->SetField( TIFFTAG_REFERENCEBLACKWHITE, $xfloatp );
                }
            }
            if ( $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_JPEG ) ==
                0 )
            {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: Unable to use JPEG compression for input %s and output %s",
                  $input->FileName(), $output->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
            $output->SetField( TIFFTAG_JPEGTABLESMODE, 0 );

            if ( $t2p->{pdf_colorspace} & ( $T2P_CS_RGB | $T2P_CS_LAB ) ) {
                $output->SetField( TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_YCBCR );
                if ( $t2p->{tiff_photometric} != PHOTOMETRIC_YCBCR ) {
                    $output->SetField( TIFFTAG_JPEGCOLORMODE,
                        JPEGCOLORMODE_RGB );
                }
                else {
                    $output->SetField( TIFFTAG_JPEGCOLORMODE,
                        JPEGCOLORMODE_RAW );
                }
            }
            if ( $t2p->{pdf_colorspace} & $T2P_CS_GRAY ) {
                0;
            }
            if ( $t2p->{pdf_colorspace} & $T2P_CS_CMYK ) {
                0;
            }
            if ( $t2p->{pdf_defaultcompressionquality} != 0 ) {
                $output->SetField( TIFFTAG_JPEGQUALITY,
                    $t2p->{pdf_defaultcompressionquality} );
            }

        }
        when ($T2P_COMPRESS_ZIP) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_DEFLATE );
            if ( $t2p->{pdf_defaultcompressionquality} % 100 != 0 ) {
                $output->SetField( TIFFTAG_PREDICTOR,
                    $t2p->{pdf_defaultcompressionquality} % 100 );
            }
            if ( $t2p->{pdf_defaultcompressionquality} / 100 != 0 ) {
                $output->SetField( TIFFTAG_ZIPQUALITY,
                    ( $t2p->{pdf_defaultcompressionquality} / 100 ) );
            }
        }
    }

    t2p_enable($output);
    $t2p->{outputwritten} = 0;
    my $bufferoffset;
    if (   $t2p->{pdf_compression} == $T2P_COMPRESS_JPEG
        && $t2p->{tiff_photometric} == PHOTOMETRIC_YCBCR )
    {
        $bufferoffset =
          $output->WriteEncodedStrip( 0, $buffer, $stripsize * $stripcount );
    }
    else {
        $bufferoffset =
          $output->WriteEncodedStrip( 0, $buffer, $t2p->{tiff_datasize} );
    }

    if ( $bufferoffset == -1 ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Error writing encoded strip to output PDF %s",
          $output->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }

    $written = $t2p->{outputwritten};
    return $written;
}

# This function reads the raster image data from the input TIFF for an image
# tile and writes the data to the output PDF XObject image dictionary stream
# for the tile.  It returns the amount written or zero on error.

sub t2p_readwrite_pdf_image_tile {
    my ( $t2p, $input, $output, $tile ) = @_;

    my $edge         = 0;
    my $written      = 0;
    my $read         = 0;
    my $tilecount    = 0;
    my $tilesize     = 0;
    my $septilecount = 0;
    my $septilesize  = 0;
    my ($buffer);

    # Fail if prior error (in particular, can't trust tiff_datasize)
    if ( $t2p->{t2p_error} != $T2P_ERR_OK ) { return 0 }

    $edge |=
      t2p_tile_is_right_edge( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile );
    $edge |=
      t2p_tile_is_bottom_edge( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile );

    if (
        $t2p->{pdf_transcode} == $T2P_TRANSCODE_RAW
        && (   $edge == 0
            || $t2p->{pdf_compression} == $T2P_COMPRESS_JPEG )
      )
    {
        if ( $t2p->{pdf_compression} == $T2P_COMPRESS_G4 ) {
            $buffer = $input->ReadRawTile( $tile, $t2p->{tiff_datasize} );
            if ( $t2p->{tiff_fillorder} == FILLORDER_LSB2MSB ) {
                TIFFReverseBits( $buffer, $t2p->{tiff_datasize} );
            }
            $output .= $buffer;
            return $t2p->{tiff_datasize};
        }
        if ( $t2p->{pdf_compression} == $T2P_COMPRESS_ZIP ) {
            $buffer = $input->ReadRawTile( $tile, $t2p->{tiff_datasize} );
            if ( $t2p->{tiff_fillorder} == FILLORDER_LSB2MSB ) {
                TIFFReverseBits( $buffer, $t2p->{tiff_datasize} );
            }
            $output .= $buffer;
            return $t2p->{tiff_datasize};
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_OJPEG ) {
            if ( !$t2p->{pdf_ojpegdata} ) {
                my $msg =
                  sprintf
"$TIFF2PDF_MODULE: No support for OJPEG image %s with bad tables",
                  $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
            $buffer = $t2p->{pdf_ojpegdata};
            if ( $edge != 0 ) {
                if (
                    t2p_tile_is_bottom_edge(
                        $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile
                    )
                  )
                {
                    substr( $buffer, 7 ) =
                      ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]
                          {tiles_edgetilelength} >> 8 ) & 0xff;
                    substr( $buffer, 8 ) =
                      ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]
                          {tiles_edgetilelength} ) & 0xff;
                }
                if (
                    t2p_tile_is_right_edge(
                        $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile
                    )
                  )
                {
                    substr( $buffer, 9 ) =
                      ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]
                          {tiles_edgetilewidth} >> 8 ) & 0xff;
                    substr( $buffer, 10 ) =
                      ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]
                          {tiles_edgetilewidth} ) & 0xff;
                }
            }
            my $bufferoffset = $t2p->{pdf_ojpegdatalength};

            $buffer .= $input->ReadRawTile( $tile, -1 );
            $buffer .= chr(0xff);
            $buffer .= chr(0xd9);
            $output .= $buffer;
            return length $buffer;
        }
        if ( $t2p->{tiff_compression} == COMPRESSION_JPEG ) {
            my $count = 0;
            my $jpt;
            my @table_end;
            if ( ( my ( $count, $jpt ) = $input->GetField(TIFFTAG_JPEGTABLES) )
                != 0 )
            {
                if ( $count > 0 ) {
                    $buffer = $jpt;
                    my $xuint32 = length($buffer) - $count - 2;
                    $table_end[0] = substr( $buffer, -2 );
                    $table_end[1] = substr( $buffer, -1 );
                    $buffer = substr( $buffer, 0, -2 );
                    $buffer .= $input->ReadRawTile( $tile, -1 );
                    substr( $buffer, $xuint32 - 2 ) = $table_end[0];
                    substr( $buffer, $xuint32 - 1 ) = $table_end[1];
                }
                else {
                    $buffer .= $input->ReadRawTile( $tile, -1 );
                }
            }
            $output .= $buffer;
            return length $buffer;
        }
        0;
    }

    if ( $t2p->{pdf_sample} == $T2P_SAMPLE_NOTHING ) {
        my $samplebuffer =
          $input->ReadEncodedTile( $tile, $t2p->{tiff_datasize} );
        if ( length $samplebuffer == 0 ) {
            my $msg =
              sprintf "$TIFF2PDF_MODULE: Error on decoding tile %u of %s",
              $tile, $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return 0;
        }
        $buffer .= $samplebuffer;

    }
    else {
        if ( $t2p->{pdf_sample} == $T2P_SAMPLE_PLANAR_SEPARATE_TO_CONTIG ) {
            my $septilesize  = $input->TIFFTileSize();
            my $septilecount = $input->TIFFNumberOfTiles();
            my $tilesize     = $septilesize * $t2p->{tiff_samplesperpixel};
            my $tilecount    = $septilecount / $t2p->{tiff_samplesperpixel};
            my $samplebuffer;
            for my $i ( 0 .. $t2p->{tiff_samplesperpixel} - 1 ) {
                my $tilebuffer =
                  $input->TIFFReadEncodedTile( $tile + $i * $tilecount,
                    $septilesize );
                if ( length $tilebuffer == 0 ) {
                    my $msg =
                      sprintf
                      "$TIFF2PDF_MODULE: Error on decoding tile %u of %s",
                      $tile + $i * $tilecount, $input->FileName();
                    warn "$msg\n";
                    $t2p->{t2p_error} = $T2P_ERR_ERROR;
                    return 0;
                }
                $samplebuffer .= $tilebuffer;
            }
            $buffer .=
              t2p_sample_planar_separate_to_contig( $t2p, $samplebuffer,
                length $samplebuffer );
        }

        if ( length $buffer == 0 ) {
            $buffer = $input->ReadEncodedTile( $tile, $t2p->{tiff_datasize} );
            if ( length $buffer == 0 ) {
                my $msg =
                  sprintf "$TIFF2PDF_MODULE: Error on decoding tile %u of %s",
                  $tile, $input->FileName();
                warn "$msg\n";
                $t2p->{t2p_error} = $T2P_ERR_ERROR;
                return 0;
            }
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_RGBA_TO_RGB ) {
            $t2p->{tiff_datasize} = t2p_sample_rgba_to_rgb(
                $buffer,
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth},
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength}
            );
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_RGBAA_TO_RGB ) {
            $t2p->{tiff_datasize} = t2p_sample_rgbaa_to_rgb(
                $buffer,
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth},
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength}
            );
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_YCBCR_TO_RGB ) {
            my $msg =
              sprintf
              "$TIFF2PDF_MODULE: No support for YCbCr to RGB in tile for %s",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return 0;
        }

        if ( $t2p->{pdf_sample} & $T2P_SAMPLE_LAB_SIGNED_TO_UNSIGNED ) {
            $t2p->{tiff_datasize} = t2p_sample_lab_signed_to_unsigned(
                $buffer,
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth},
                $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength}
            );
        }
    }

    if ( t2p_tile_is_right_edge( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile )
        != 0 )
    {
        t2p_tile_collapse_left(
            $buffer,
            $input->TileRowSize(),
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth},
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_edgetilewidth},
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength}
        );
    }

    t2p_disable($output);
    $output->SetField( TIFFTAG_PHOTOMETRIC,     $t2p->{tiff_photometric} );
    $output->SetField( TIFFTAG_BITSPERSAMPLE,   $t2p->{tiff_bitspersample} );
    $output->SetField( TIFFTAG_SAMPLESPERPIXEL, $t2p->{tiff_samplesperpixel} );
    if ( t2p_tile_is_right_edge( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile )
        == 0 )
    {
        $output->TIFFSetField( TIFFTAG_IMAGEWIDTH,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth} );
    }
    else {
        $output->SetField( TIFFTAG_IMAGEWIDTH,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_edgetilewidth} );
    }
    if (
        t2p_tile_is_bottom_edge(
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ], $tile
        ) == 0
      )
    {
        $output->SetField( TIFFTAG_IMAGELENGTH,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength} );
        $output->TIFFSetField( TIFFTAG_ROWSPERSTRIP,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength} );
    }
    else {
        $output->SetField( TIFFTAG_IMAGELENGTH,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_edgetilelength} );
        $output->SetField( TIFFTAG_ROWSPERSTRIP,
            $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_edgetilelength} );
    }
    $output->SetField( TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG );
    $output->SetField( TIFFTAG_FILLORDER,    FILLORDER_MSB2LSB );

    given ( $t2p->{pdf_compression} ) {
        when ($T2P_COMPRESS_NONE) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_NONE );
        }
        when ($T2P_COMPRESS_G4) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_CCITTFAX4 );
        }
        when ($T2P_COMPRESS_JPEG) {
            if ( $t2p->{tiff_photometric} == PHOTOMETRIC_YCBCR ) {
                my $hor = 0;
                my $ver = 0;
                ( $hor, $ver ) = $input->GetField(TIFFTAG_YCBCRSUBSAMPLING);
                if ( $hor != 0 && $ver != 0 ) {
                    $output->SetField( TIFFTAG_YCBCRSUBSAMPLING, $hor, $ver );
                }
                if ( my $xfloatp =
                    $input->GetField(TIFFTAG_REFERENCEBLACKWHITE) != 0 )
                {
                    $output->SetField( TIFFTAG_REFERENCEBLACKWHITE, $xfloatp );
                }
            }
            $output->SetField( TIFFTAG_COMPRESSION,    COMPRESSION_JPEG );
            $output->SetField( TIFFTAG_JPEGTABLESMODE, 0 )
              ;    # JPEGTABLESMODE_NONE
            if ( $t2p->{pdf_colorspace} & ( $T2P_CS_RGB | $T2P_CS_LAB ) ) {
                $output->SetField( TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_YCBCR );
                if ( $t2p->{tiff_photometric} != PHOTOMETRIC_YCBCR ) {
                    $output->SetField( TIFFTAG_JPEGCOLORMODE,
                        JPEGCOLORMODE_RGB );
                }
                else {
                    $output->SetField( TIFFTAG_JPEGCOLORMODE,
                        JPEGCOLORMODE_RAW );
                }
            }
            if ( $t2p->{pdf_colorspace} & $T2P_CS_GRAY ) {
                0;
            }
            if ( $t2p->{pdf_colorspace} & $T2P_CS_CMYK ) {
                0;
            }
            if ( $t2p->{pdf_defaultcompressionquality} != 0 ) {
                $output->SetField( TIFFTAG_JPEGQUALITY,
                    $t2p->{pdf_defaultcompressionquality} );
            }
        }
        when ($T2P_COMPRESS_ZIP) {
            $output->SetField( TIFFTAG_COMPRESSION, COMPRESSION_DEFLATE );
            if ( $t2p->{pdf_defaultcompressionquality} % 100 != 0 ) {
                $output->SetField( TIFFTAG_PREDICTOR,
                    $t2p->{pdf_defaultcompressionquality} % 100 );
            }
            if ( $t2p->{pdf_defaultcompressionquality} / 100 != 0 ) {
                $output->SetField( TIFFTAG_ZIPQUALITY,
                    ( $t2p->{pdf_defaultcompressionquality} / 100 ) );
            }
        }
    }

    t2p_enable($output);
    $t2p->{outputwritten} = 0;
    my $bufferoffset =
      $output->TIFFWriteEncodedStrip( 0, $buffer, $output->StripSize() );
    if ( $bufferoffset == -1 ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Error writing encoded tile to output PDF %s",
          $output->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }

    return $t2p->{outputwritten};
}

sub t2p_process_ojpeg_tables {
    my ( $t2p, $input ) = @_;

    my (
        $proc,      $q_length, $q,      $dc_length,
        $dc,        $h_samp,   $v_samp, $code_count,
        $ac_length, $ac,       $lp,     $pt
    );
    if ( !( $proc = $input->GetField(TIFFTAG_JPEGPROC) ) ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: Missing JPEGProc field in OJPEG image %s",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    if ( $proc != JPEGPROC_BASELINE && $proc != JPEGPROC_LOSSLESS ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: Bad JPEGProc field in OJPEG image %s",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    if ( !( ( $q_length, $q ) = $input->GetField(TIFFTAG_JPEGQTABLES) ) ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Missing JPEGQTables field in OJPEG image %s",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    if ( $q_length < ( 64 * $t2p->{tiff_samplesperpixel} ) ) {
        my $msg =
          sprintf "$TIFF2PDF_MODULE: Bad JPEGQTables field in OJPEG image %s",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    if ( !( ( $dc_length, $dc ) = $input->GetField(TIFFTAG_JPEGDCTABLES) ) ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Missing JPEGDCTables field in OJPEG image %s",
          $input->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    if ( $proc == JPEGPROC_BASELINE ) {
        if ( !( ( $ac_length, $ac ) = $input->GetField(TIFFTAG_JPEGACTABLES) ) )
        {
            my $msg =
              sprintf
              "$TIFF2PDF_MODULE: Missing JPEGACTables field in OJPEG image %s",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return 0;
        }
    }
    else {
        $lp = $input->GetField(TIFFTAG_JPEGLOSSLESSPREDICTORS);
        if ( !defined $lp ) {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: Missing JPEGLosslessPredictors field in OJPEG image %s",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return 0;
        }
        $pt = $input->GetField(TIFFTAG_JPEGPOINTTRANSFORM);
        if ( !defined $pt ) {
            my $msg =
              sprintf
"$TIFF2PDF_MODULE: Missing JPEGPointTransform field in OJPEG image %s",
              $input->FileName();
            warn "$msg\n";
            $t2p->{t2p_error} = $T2P_ERR_ERROR;
            return 0;
        }
    }
    if (
        !(
            ( $h_samp, $v_samp ) =
            $input->TIFFGetField(TIFFTAG_YCBCRSUBSAMPLING)
        )
      )
    {
        $h_samp = 1;
        $v_samp = 1;
    }
    my $table_count = $t2p->{tiff_samplesperpixel};
    if ( $proc == JPEGPROC_BASELINE and $table_count > 2 ) { $table_count = 2 }
    my $ojpegdata = $t2p->{pdf_ojpegdata};
    $ojpegdata .= chr 0xff;
    $ojpegdata .= chr 0xd8;
    $ojpegdata .= chr 0xff;
    if ( $proc == JPEGPROC_BASELINE ) {
        $ojpegdata .= chr 0xc0;
    }
    else {
        $ojpegdata .= chr 0xc3;
    }
    $ojpegdata .= chr 0x00;
    $ojpegdata .= chr( 8 + 3 * $t2p->{tiff_samplesperpixel} );
    $ojpegdata .= chr( $t2p->{tiff_bitspersample} & 0xff );
    if ( $input->IsTiled() ) {
        $ojpegdata .= chr(
            ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength} >> 8 ) &
              0xff );
        $ojpegdata .=
          chr( ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilelength} ) &
              0xff );
        $ojpegdata .= chr(
            ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth} >> 8 ) &
              0xff );
        $ojpegdata .=
          chr( ( $t2p->{tiff_tiles}[ $t2p->{pdf_page} ]{tiles_tilewidth} ) &
              0xff );
    }
    else {
        $ojpegdata .= chr( ( $t2p->{tiff_length} >> 8 ) & 0xff );
        $ojpegdata .= chr( $t2p->{tiff_length} & 0xff );
        $ojpegdata .= chr( ( $t2p->{tiff_width} >> 8 ) & 0xff );
        $ojpegdata .= chr( $t2p->{tiff_width} & 0xff );
    }
    $ojpegdata .= chr( $t2p->{tiff_samplesperpixel} & 0xff );
    for my $i ( 0 .. $t2p->{tiff_samplesperpixel} - 1 ) {
        $ojpegdata .= chr $i;
        if ( $i == 0 ) {
            substr( $ojpegdata, -1 ) |= chr( $h_samp << 4 & 0xf0 );
            $ojpegdata .= chr( $v_samp & 0x0f );
        }
        else {
            $ojpegdata .= chr 0x11;
        }
        $ojpegdata .= chr $i;
    }
    for my $dest ( 0 .. $t2p->{tiff_samplesperpixel} - 1 ) {
        $ojpegdata .= chr 0xff;
        $ojpegdata .= chr 0xdb;
        $ojpegdata .= chr 0x00;
        $ojpegdata .= chr 0x43;
        $ojpegdata .= chr $dest;
        $ojpegdata .= substr $q, 64 * $dest, 64;
    }
    my $offset_table = 0;
    for my $dest ( 0 .. $table_count - 1 ) {
        $ojpegdata .= chr 0xff;
        $ojpegdata .= chr 0xc4;
        my $offset_ms_l = length $ojpegdata;
        $ojpegdata .= '..';                  #placeholders to be filled below
        $ojpegdata .= chr( $dest & 0x0f );
        $ojpegdata .= substr $dc, $offset_table, 16;
        $code_count = 0;
        $offset_table += 16;

        for my $i ( 0 .. 15 ) {
            $code_count += ord substr( $ojpegdata, $i - 16, 1 );
        }
        substr( $ojpegdata, $offset_ms_l ) =
          chr( ( ( 19 + $code_count ) >> 8 ) & 0xff );
        substr( $ojpegdata, $offset_ms_l + 1 ) =
          chr( ( 19 + $code_count ) & 0xff );
        $ojpegdata .= substr $dc, $offset_table, $code_count;
        $offset_table += $code_count;
    }
    if ( $proc == JPEGPROC_BASELINE ) {
        $offset_table = 0;
        for my $dest ( 0 .. $table_count - 1 ) {
            $ojpegdata .= chr 0xff;
            $ojpegdata .= chr 0xc4;
            my $offset_ms_l = length $ojpegdata;
            $ojpegdata .= '..';                 #placeholders to be filled below
            $ojpegdata .= chr 0x10;
            $ojpegdata .= chr( $dest & 0x0f );
            $ojpegdata .= substr $ac, $offset_table, 16;
            $code_count = 0;
            $offset_table += 16;

            for my $i ( 0 .. 15 ) {
                $code_count += ord substr( $ojpegdata, $i - 16, 1 );
            }
            substr( $ojpegdata, $offset_ms_l ) =
              chr( ( ( 19 + $code_count ) >> 8 ) & 0xff );
            substr( $ojpegdata, $offset_ms_l + 1 ) =
              chr( ( 19 + $code_count ) & 0xff );
            $ojpegdata .= substr $dc, $offset_table, $code_count;
            $offset_table += $code_count;
        }
    }
    if ( $input->NumberOfStrips() > 1 ) {
        $ojpegdata .= chr 0xff;
        $ojpegdata .= chr 0xdd;
        $ojpegdata .= chr 0x00;
        $ojpegdata .= chr 0x04;
        $h_samp *= 8;
        $v_samp *= 8;
        my $ri = ( $t2p->{tiff_width} + $h_samp - 1 ) / $h_samp;
        my $rows->$input->GetField(TIFFTAG_ROWSPERSTRIP);
        $ri *= ( $rows + $v_samp - 1 ) / $v_samp;
        $ojpegdata .= chr( ( $ri >> 8 ) & 0xff );
        $ojpegdata .= chr( $ri & 0xff );
    }
    $ojpegdata .= chr 0xff;
    $ojpegdata .= chr 0xda;
    $ojpegdata .= chr 0x00;
    $ojpegdata .= chr( 6 + 2 * $t2p->{tiff_samplesperpixel} );
    $ojpegdata .= chr( $t2p->{tiff_samplesperpixel} & 0xff );
    for my $i ( 0 .. t2p->tiff_samplesperpixel- 1 ) {
        $ojpegdata .= chr( $i & 0xff );
        if ( $proc == JPEGPROC_BASELINE ) {
            $ojpegdata .= chr(
                (
                    (
                          ( $i > ( $table_count - 1 ) )
                        ? ( $table_count - 1 )
                        : $i
                    ) << 4
                ) & 0xf0
            );
            $ojpegdata .= chr(
                ( ( $i > ( $table_count - 1 ) ) ? ( $table_count - 1 ) : $i ) &
                  0x0f );
        }
        else {
            $ojpegdata .= chr( ( $i << 4 ) & 0xf0 );
        }
    }
    if ( $proc == JPEGPROC_BASELINE ) {
        $ojpegdata .= chr 0x00;
        $ojpegdata .= chr 0x3f;
        $ojpegdata .= chr 0x00;
    }
    else {
        $ojpegdata .= chr( substr( $lp, 0 ) & 0xff );
        $ojpegdata .= chr 0x00;
        $ojpegdata .= chr( substr( $pt, 0 ) & 0x0f );
    }

    return 1;
}

sub t2p_process_jpeg_strip {
    my ( $strip, $striplength, $buffer, $bufferoffset, $no, $height ) = @_;

    my $v_samp = 1;
    my $h_samp = 1;
    my $i      = 1;
    while ( $i < $striplength ) {
        given ( ord( substr( $i, 1 ) ) ) {
            when (0xd8) {

                # SOI - start of image
                $buffer .= substr( $strip, $i - 1, 2 );
                $i += 2;
            }
            when ( ( 0xc0 | 0xc1 | 0xc3 | 0xc9 | 0xca ) ) {
                if ( $no == 0 ) {
                    $bufferoffset = length $buffer;
                    $buffer .=
                      substr( $strip, $i - 1,
                        ord( substr( $strip, $i + 2, 1 ) ) + 2 );
                    for my $j (
                        0 .. ord( substr( $buffer, $bufferoffset + 9, 1 ) ) )
                    {
                        if (
                            (
                                ord(
                                    substr(
                                        $buffer,
                                        $bufferoffset + 11 + ( 2 * $j ), 1
                                    )
                                ) >> 4
                            ) > $h_samp
                          )
                        {
                            $h_samp = ord(
                                substr(
                                    $buffer, $bufferoffset + 11 + ( 2 * $j ),
                                    1
                                )
                            ) >> 4;
                        }
                        if (
                            (
                                ord(
                                    substr(
                                        $buffer,
                                        $bufferoffset + 11 + ( 2 * $j ), 1
                                    )
                                ) & 0x0f
                            ) > $v_samp
                          )
                        {
                            $v_samp = ord(
                                substr(
                                    $buffer, $bufferoffset + 11 + ( 2 * $j ),
                                    1
                                )
                            ) & 0x0f;
                        }
                    }
                    $v_samp *= 8;
                    $h_samp *= 8;
                    my $ri = (
                        (
                            ( substr( $buffer, $bufferoffset + 5, 1 ) << 8 ) |
                              substr( $buffer, $bufferoffset + 6, 1 )
                        ) + $v_samp - 1
                      ) /
                      $v_samp;
                    $ri *= (
                        (
                            ( substr( $buffer, $bufferoffset + 7, 1 ) << 8 ) |
                              substr( $buffer, $bufferoffset + 8, 1 )
                        ) + $h_samp - 1
                      ) /
                      $h_samp;
                    substr( $buffer, $bufferoffset + 5, 1 ) =
                      ( $height >> 8 ) & 0xff;
                    substr( $buffer, $bufferoffset + 6, 1 ) = $height & 0xff;
                    $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;

                    $buffer .= chr 0xff;
                    $buffer .= chr 0xdd;
                    $buffer .= chr 0x00;
                    $buffer .= chr 0x04;
                    $buffer .= chr( ( $ri >> 8 ) & 0xff );
                    $buffer .= chr( $ri & 0xff );
                }
                else {
                    $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;
                }
            }
            when ( ( 0xc4 | 0xdb ) ) {
                $buffer .=
                  substr( $strip, $i - 1,
                    ord( substr( $strip, $i + 2, 1 ) ) + 2 );
                $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;
            }
            when (0xda) {
                if ( $no == 0 ) {
                    $buffer .=
                      substr( $strip, $i - 1,
                        ord( substr( $strip, $i + 2, 1 ) ) + 2 );
                    $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;
                }
                else {
                    $buffer .= chr 0xff;
                    $buffer .= chr( 0xd0 | ( ( $no - 1 ) % 8 ) );
                    $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;
                }
                $buffer .= substr( $strip, $i - 1, $striplength - $i - 1 );
                return 1;
            }
            default {
                $i += ord( substr( $strip, $i + 2, 1 ) ) + 2;
            }
        }
    }

    return 0;
}

# This functions converts a tilewidth x tilelength buffer of samples into an edgetilewidth x
# tilelength buffer of samples.

sub t2p_tile_collapse_left {
    my ( $buffer, $scanwidth, $tilewidth, $edgetilewidth, $tilelength ) = @_;

    my $edgescanwidth =
      ( $scanwidth * $edgetilewidth + ( $tilewidth - 1 ) ) / $tilewidth;
    for my $i ( 0 .. $tilelength - 1 ) {
        substr( $buffer, $edgescanwidth * $i, $edgescanwidth ) =
          substr( $buffer, $scanwidth * $i, $edgescanwidth );
    }

    return;
}

# This function calls TIFFWriteDirectory on the output after blanking its
# output by replacing the read, write, and seek procedures with empty
# implementations, then it replaces the original implementations.

sub t2p_write_advance_directory {
    my ( $t2p, $output ) = @_;
    t2p_disable($output);
    if ( !$output->WriteDirectory() ) {
        my $msg =
          sprintf
          "$TIFF2PDF_MODULE: Error writing virtual directory to output PDF %s",
          $output->FileName();
        warn "$msg\n";
        $t2p->{t2p_error} = $T2P_ERR_ERROR;
        return 0;
    }
    t2p_enable($output);
    return;
}

sub t2p_sample_planar_separate_to_contig {
    my ( $t2p, $buffer, $samplebuffer, $samplebuffersize ) = @_;

    my $stride = $samplebuffersize / $t2p->{tiff_samplesperpixel};
    for my $i ( 0 .. $stride - 1 ) {
        for my $j ( 0 .. $t2p->{tiff_samplesperpixel} - 1 ) {
            substr( $buffer, $i * $t2p->{tiff_samplesperpixel} + $j, 1 ) =
              substr( $samplebuffer, $i + $j * $stride, 1 );
        }
    }

    return $samplebuffersize;
}

exit main();
