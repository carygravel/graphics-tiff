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
tiff_SetDirectory (tif, dirnum)
                TIFF		*tif
                uint16          dirnum;
        PPCODE:
	        XPUSHs(sv_2mortal(newSViv(TIFFSetDirectory(tif, dirnum))));

void
tiff_GetField (tif, tag)
                TIFF            *tif
                uint32          tag
	INIT:
                uint32          v1, v2, v3, v4;
        PPCODE:
                switch (items) {
                        case 2: if (TIFFGetField (tif, tag, &v1)) {
                                        XPUSHs(sv_2mortal(newSViv(v1)));
                                }
                                break;
                        case 3: if (TIFFGetField (tif, tag, &v1, &v2)) {
                                        XPUSHs(sv_2mortal(newSViv(v1)));
                                        XPUSHs(sv_2mortal(newSViv(v2)));
                                }
                                break;
                        case 4: if (TIFFGetField (tif, tag, &v1, &v2, &v3)) {
                                        XPUSHs(sv_2mortal(newSViv(v1)));
                                        XPUSHs(sv_2mortal(newSViv(v2)));
                                        XPUSHs(sv_2mortal(newSViv(v3)));
                                }
                                break;
                        case 5: if (TIFFGetField (tif, tag, &v1, &v2, &v3, &v4)) {
                                        XPUSHs(sv_2mortal(newSViv(v1)));
                                        XPUSHs(sv_2mortal(newSViv(v2)));
                                        XPUSHs(sv_2mortal(newSViv(v3)));
                                        XPUSHs(sv_2mortal(newSViv(v4)));
                                }
                                break;
                } 

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
