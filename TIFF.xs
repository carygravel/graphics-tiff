#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <tiffperl.h>

MODULE = Graphics::TIFF		PACKAGE = Graphics::TIFF	  PREFIX = tiff_

PROTOTYPES: ENABLE
  
BOOT:
	HV *stash;
	stash = gv_stashpv("Graphics::TIFF", TRUE);

	newCONSTSUB(stash, "TIFFTAG_IMAGEWIDTH", newSViv(TIFFTAG_IMAGEWIDTH));
	newCONSTSUB(stash, "TIFFTAG_IMAGELENGTH", newSViv(TIFFTAG_IMAGELENGTH));

	newCONSTSUB(stash, "TIFFTAG_FILLORDER", newSViv(TIFFTAG_FILLORDER));
	newCONSTSUB(stash, "FILLORDER_MSB2LSB", newSViv(FILLORDER_MSB2LSB));
	newCONSTSUB(stash, "FILLORDER_LSB2MSB", newSViv(FILLORDER_LSB2MSB));

	newCONSTSUB(stash, "TIFFTAG_ROWSPERSTRIP", newSViv(TIFFTAG_ROWSPERSTRIP));
	newCONSTSUB(stash, "TIFFTAG_STRIPBYTECOUNTS", newSViv(TIFFTAG_STRIPBYTECOUNTS));

	newCONSTSUB(stash, "TIFFTAG_XRESOLUTION", newSViv(TIFFTAG_XRESOLUTION));
	newCONSTSUB(stash, "TIFFTAG_YRESOLUTION", newSViv(TIFFTAG_YRESOLUTION));

	newCONSTSUB(stash, "TIFFTAG_PLANARCONFIG", newSViv(TIFFTAG_PLANARCONFIG));
	newCONSTSUB(stash, "PLANARCONFIG_CONTIG", newSViv(PLANARCONFIG_CONTIG));

	newCONSTSUB(stash, "TIFFTAG_PAGENUMBER", newSViv(TIFFTAG_PAGENUMBER));

	newCONSTSUB(stash, "TIFFTAG_EXIFIFD", newSViv(TIFFTAG_EXIFIFD));

	newCONSTSUB(stash, "TIFFPRINT_CURVES", newSViv(TIFFPRINT_CURVES));
	newCONSTSUB(stash, "TIFFPRINT_COLORMAP", newSViv(TIFFPRINT_COLORMAP));
	newCONSTSUB(stash, "TIFFPRINT_JPEGQTABLES", newSViv(TIFFPRINT_JPEGQTABLES));
	newCONSTSUB(stash, "TIFFPRINT_JPEGACTABLES", newSViv(TIFFPRINT_JPEGACTABLES));
	newCONSTSUB(stash, "TIFFPRINT_JPEGDCTABLES", newSViv(TIFFPRINT_JPEGDCTABLES));

void
tiff_GetVersion (class)
        PPCODE:
                XPUSHs(sv_2mortal(newSVpv((char *) TIFFGetVersion(), 0)));

void
tiff__Open (class, path, flags)
		const char*	path
		const char*	flags
	INIT:
                TIFF		*tif;
        PPCODE:
                tif = TIFFOpen(path, flags);
                XPUSHs(sv_2mortal(newSViv(PTR2IV(tif))));

void
tiff_Close (tif)
                TIFF		*tif;
        PPCODE:
                TIFFClose(tif);

void
tiff_ReadDirectory (tif)
                TIFF		*tif;
        PPCODE:
	        XPUSHs(sv_2mortal(newSViv(TIFFReadDirectory(tif))));

void
tiff_ReadEXIFDirectory (tif, diroff)
                TIFF		*tif
                toff_t          diroff;
        PPCODE:
	        XPUSHs(sv_2mortal(newSViv(TIFFReadEXIFDirectory(tif, diroff))));

void
tiff_SetDirectory (tif, dirnum)
                TIFF		*tif
                uint16          dirnum;
        PPCODE:
	        XPUSHs(sv_2mortal(newSViv(TIFFSetDirectory(tif, dirnum))));

void
tiff_SetSubDirectory(tif, diroff)
                TIFF		*tif
                uint64          diroff;
        PPCODE:
	        XPUSHs(sv_2mortal(newSViv(TIFFSetSubDirectory(tif, diroff))));

void
tiff_GetField (tif, tag)
                TIFF            *tif
                uint32          tag
	INIT:
                uint16          ui16, ui16_2;
                uint32          ui32;
                uint64          *aui;
                float           f;
                int             vector_length;
        PPCODE:
                switch (tag) {
                    /* single uint16 */
		    case TIFFTAG_BITSPERSAMPLE:
		    case TIFFTAG_COMPRESSION:
		    case TIFFTAG_PHOTOMETRIC:
		    case TIFFTAG_THRESHHOLDING:
		    case TIFFTAG_FILLORDER:
		    case TIFFTAG_ORIENTATION:
		    case TIFFTAG_SAMPLESPERPIXEL:
		    case TIFFTAG_MINSAMPLEVALUE:
		    case TIFFTAG_MAXSAMPLEVALUE:
		    case TIFFTAG_PLANARCONFIG:
		    case TIFFTAG_RESOLUTIONUNIT:
		    case TIFFTAG_MATTEING:
                        if (TIFFGetField (tif, tag, &ui16)) {
                            XPUSHs(sv_2mortal(newSViv(ui16)));
                        }
                        break;

                    /* single float */
		    case TIFFTAG_XRESOLUTION:
		    case TIFFTAG_YRESOLUTION:
		    case TIFFTAG_XPOSITION:
		    case TIFFTAG_YPOSITION:
                        if (TIFFGetField (tif, tag, &f)) {
                            XPUSHs(sv_2mortal(newSVnv(f)));
                        }
                        break;

                    /* two uint16 */
		    case TIFFTAG_PAGENUMBER:
		    case TIFFTAG_HALFTONEHINTS:
                        if (TIFFGetField (tif, tag, &ui16, &ui16_2)) {
                            XPUSHs(sv_2mortal(newSViv(ui16)));
                            XPUSHs(sv_2mortal(newSViv(ui16_2)));
                        }
                        break;

                    /* array of uint64 */
                    case TIFFTAG_TILEOFFSETS:
                    case TIFFTAG_TILEBYTECOUNTS:
                    case TIFFTAG_STRIPOFFSETS:
                    case TIFFTAG_STRIPBYTECOUNTS:
                        if (TIFFGetField (tif, tag, &aui)) {
                            int nstrips = TIFFNumberOfStrips(tif);
                            int i;
			    for (i = 0; i < nstrips; ++i)
                                XPUSHs(sv_2mortal(newSViv(aui[i])));
                        }
                        break;

                    /* single uint32 */
                    default:
                        if (TIFFGetField (tif, tag, &ui32)) {
                            XPUSHs(sv_2mortal(newSViv(ui32)));
                        }
                        break;
                }

void
tiff_SetField (tif, tag, v1, ...)
                TIFF            *tif
                uint32          tag
                uint32          v1
        PPCODE:
                switch (items) {
                        case 3: XPUSHs(sv_2mortal(newSViv(TIFFSetField (tif, tag, v1))));
                                break;
                        case 4: XPUSHs(sv_2mortal(newSViv(TIFFSetField (tif, tag, v1, ST(3)))));
                                break;
                        case 5: XPUSHs(sv_2mortal(newSViv(TIFFSetField (tif, tag, v1, ST(3), ST(4)))));
                                break;
                        case 6: XPUSHs(sv_2mortal(newSViv(TIFFSetField (tif, tag, v1, ST(3), ST(4), ST(5)))));
                                break;
                }

void
tiff_IsTiled (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFIsTiled(tif))));

void
tiff_ScanlineSize (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFScanlineSize(tif))));

void
tiff_StripSize (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFStripSize(tif))));

void
tiff_NumberOfStrips (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFNumberOfStrips(tif))));

void
tiff_TileSize (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFTileSize(tif))));

void
tiff_TileRowSize (tif)
                TIFF            *tif
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFTileRowSize(tif))));

void
tiff_ComputeStrip (tif, row, sample)
                TIFF            *tif
                uint32          row
                uint16          sample
        PPCODE:
                XPUSHs(sv_2mortal(newSViv(TIFFComputeStrip(tif, row, sample))));

void
tiff_ReadEncodedStrip (tif, strip, size)
                TIFF            *tif
                uint32          strip
                tmsize_t        size
	INIT:
                void            *buf;
                tmsize_t        stripsize;
        PPCODE:
                stripsize = TIFFStripSize(tif);
                buf = (unsigned char *)_TIFFmalloc(stripsize);
                if (TIFFReadEncodedStrip(tif, strip, buf, size)) {
                    XPUSHs(sv_2mortal(newSVpvn(buf, stripsize)));
                }
		_TIFFfree(buf);

void
tiff_ReadRawStrip (tif, strip, size)
                TIFF            *tif
                uint32          strip
                tmsize_t        size
	INIT:
                void            *buf;
                tmsize_t        stripsize;
        PPCODE:
                stripsize = TIFFStripSize(tif);
                buf = (unsigned char *)_TIFFmalloc(stripsize);
                if (TIFFReadRawStrip(tif, strip, buf, size)) {
                    XPUSHs(sv_2mortal(newSVpvn(buf, stripsize)));
                }
		_TIFFfree(buf);

void
tiff_ReadTile (tif, x, y, z, s)
                TIFF            *tif
                uint32          x
                uint32          y
                uint32          z
                uint16          s
	INIT:
                void            *buf;
                tmsize_t        tilesize;
        PPCODE:
                tilesize = TIFFTileSize(tif);
                buf = (unsigned char *)_TIFFmalloc(tilesize);
                if (TIFFReadTile(tif, buf, x, y, z, s)) {
                    XPUSHs(sv_2mortal(newSVpvn(buf, tilesize)));
                }
		_TIFFfree(buf);

void
tiff_PrintDirectory (tif, file, flags)
                TIFF            *tif
                FILE            *file
                long            flags
        CODE:
                TIFFPrintDirectory(tif, file, flags);
