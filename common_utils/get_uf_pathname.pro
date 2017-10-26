FUNCTION get_uf_pathname, ncfile, gvbegin, uf_path_prefix, UFBASE=ufbase

;=============================================================================
;+
; Copyright © 2009, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_uf_pathname.pro      Morris/SAIC/GPM_GV      February 2009
;
; DESCRIPTION
; -----------
; Retrieves the pathname of the 1C-UF file that matches, in site location and
; datetime, an instance of a geo-match netCDF file.  This routine encapsulates
; the logic to:  1) account for the different GV radar site ID conventions used
; in the geo-match netCDF files (NWS convention) and TRMM GV 1CUF file naming
; (TRMM GV convention), 2) account for the UF file naming convention for
; different UF file sources, and 3) account for local differences in the
; 'common' directory under which 1CUF files are stored.  Three parameters must
; be specified in the calling sequence:
;
;   ncfile:  the name of the geo-match netCDF file, which includes the NWS site
;            ID (in the case of WSR-88D sites) or the GPM GV assigned site ID
;            in the cases of other radars, and the YYMMDD datestamp of the data
;
;   gvbegin:  the ASCII-format date/time (YYYY-MM-DD HH:MM:SS) of the beginning
;             of the first sweep in the GV radar volume, extracted from metadata
;             in the netCDF file
;
;   uf_path_prefix:  the top-level components of the local path under which the
;                    UF files are stored, and which is common to all sites,
;                    products, and dates
;
;   ufbase :  (OPTIONAL) the basename of the specific UF file whose path below
;             uf_path_prefix is to be found
;
; The expected full pathname of the 1CUF file that matches the geo-match file
; will be constructed from components of these 3 parameters.  In the case of the
; WSR-88D radars, the GPM GV site ID will be used first in the building of the
; pathname.  If the file is not found using this site ID, the TRMM GV site ID,
; if it exists and is different from the GPM GV site ID, will then be used as an
; alternate site ID in the UF file pathname used to search for the UF file.
; Selection of the alternate siteID is coded as a CASE statement, where the
; site ID extracted from the geo-match netCDF filename is the case switch.
;
; CONSTRAINTS
; -----------
; The path to the UF files which follows after uf_path_prefix is expected to be
; of the form:  SITE_ID/PRODUCT/YYYY/MMDD, where PRODUCT is either '1CUF' or
; '1CUF-cal' (as determined from examining the ncfile name), YYYY is the 4-digit
; year, and MMDD is the month and day, with preceding zeroes included.
;
; HISTORY
; -------
; 8/21/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Created.
; 9/17/08 - Morris/NASA/GSFC (SAIC), GPM GV:  Added z_field to I/O parameters.
; 4/30/14 - Morris/NASA/GSFC (SAIC), GPM GV:  Added 2nd ufpattern to search for
;           in default site ID cases, for new dual-pol UF filename convention.
; 6/30/15 - Morris/NASA/GSFC (SAIC), GPM GV:  Added optional ufbase keyword
;           parameter to allow passing in a known UF file basename, where we
;           just need to find the path to it.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;=============================================================================


parsed = STRSPLIT( ncfile, '.', /extract )
site = parsed[1]
yymmdd = parsed[2]
addcal = ''        ; postfix to find correct KWAJ 1CUF subdirectory
IF ( site EQ 'KWAJ' and parsed[4] eq 'cal' ) THEN addcal = '-cal'

parsedatetime = STRSPLIT( gvbegin, ' ', /extract )
parseddate = STRSPLIT( parsedatetime[0], '-', /extract )
year = parseddate[0]
mon = parseddate[1]
day = parseddate[2]
monday = mon+day
parsedtime = STRSPLIT( parsedatetime[1], ':', /extract )
hh = parsedtime[0]
mm = parsedtime[1]
ss = parsedtime[2]
hhmm = hh+mm
hhmmss = hhmm+ss
hhnom = string( FIX(parsedtime[0])+1, FORMAT='(I0)' )

IF N_ELEMENTS( ufbase ) NE 0 THEN BEGIN
   ufpattern = ufbase[0]
ENDIF ELSE BEGIN
   ; Build site-specific UF filename pattern -- can't use SITE in filename,
   ;   TRMM GV site IDs can differ from VN's. "Versions" also differ between
   ;   KWAJ and others

   CASE site OF
      'RMOR' : ufpattern = 'ARMOR_'+year+monday+hhmm+'*'
      'RGSN' : BEGIN
               ; file timestamp is Korean local (UTC+9), scan time is UTC
               ; - need to recalculate path and pattern based on offset datetime
               dtimeUTC = JULDAY(mon,day,year,hh,mm,ss)
               dtimeKor = dtimeUTC + 9d/24d
               CALDAT, dtimeKor, umon, uday, uyear, uhh, umm, uss
               ufpattern = 'RDR_GSN_' + string(uyear, FORMAT='(I4)') + $
                           string(umon, FORMAT='(I02)') + $
                           string(uday, FORMAT='(I02)') + $
                           string(uhh, FORMAT='(I02)') + $
                           string(umm, FORMAT='(I02)') + '*'
               year = string(uyear, FORMAT='(I4)')
               monday = string(umon, FORMAT='(I02)') + $
                        string(uday, FORMAT='(I02)')
               END
      'DARW' : ufpattern =  'UF'+year+monday+'_'+hhmmss+'.PPI*'
       ELSE  : BEGIN
               ufpatternOld = yymmdd+'.'+hhnom+'.*.*.'+hhmm+'.uf*'
               ufpatternNew = '*_'+year+'_'+monday+'_'+hhmm+'*.uf*'
               ufpattern = '{' + ufpatternOld + ',' + ufpatternNew + '}'
               END
   ENDCASE
ENDELSE

ufpath = uf_path_prefix+'/'+site+'/'+'1CUF'+addcal+'/'+year+'/'+monday+'/'
uf2find = ufpath+ufpattern

; look for an unique 1CUF file matching this pathname: uf2find

uf_files = file_search(uf2find,COUNT=nuf)

CASE nuf OF
  1 : BEGIN
    return, uf_files[0]
  END
  0 : BEGIN
   ; see if an alternate siteID is indicated
    CASE site OF
       'KAMX' : BEGIN
                  alt = 'MIAM'
                END
       'KBYX' : BEGIN
                  alt = 'KEYW'
                END
       'KGRK' : BEGIN
                  alt = 'GRAN'
                END
       'KHGX' : BEGIN
                  alt = 'HSTN'
                END
       'KJAX' : BEGIN
                  alt = 'JACK'
                END
       'KLCH' : BEGIN
                  alt = 'LKCH'
                END
       'KMLB' : BEGIN
                  alt = 'MELB'
                END
       'KTBW' : BEGIN
                  alt = 'TAMP'
                END
       'KTLH' : BEGIN
                  alt = 'TALL'
                END
        ELSE  : BEGIN
                  alt = 'none'
                END
    ENDCASE
    IF alt NE 'none' THEN BEGIN
       ufpath2 = uf_path_prefix+'/'+alt+'/'+'1CUF'+addcal+'/'+year+'/'+monday+'/'
       uf2find2 = ufpath2+ufpattern
       uf_files = file_search(uf2find2,COUNT=nuf)
       if nuf NE 1 THEN BEGIN
          print, ''
          print, 'In get_uf_pathname(): No unique 1CUF file matching file patterns: '
          print, '   ', uf2find
          print, '   ', uf2find2
          print, ''
          return, 'Not found'
       endif
    ENDIF ELSE BEGIN
       print, ''
       print, 'In get_uf_pathname(): No unique 1CUF file matching file pattern: ', uf2find
       print, ''
       return, 'Not found'
     ENDELSE
  END
  ELSE : BEGIN
    print, ''
    print, 'In get_uf_pathname(): No unique 1CUF file matching file pattern: ', uf2find
    print, ''
    return, 'Not found'
  END
ENDCASE

return, uf_files[0]
END
