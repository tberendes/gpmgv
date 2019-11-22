;       data8='12648|55332|DARW|Thu 02 Aug 00:00:00 2007|28.1133|-80.6542|0.011|DARW/1CUF/2007/0304/UF20070304_102001.PPI.gz'
    in_base_dir = '/data/gv_radar/finalQC_in/'  ;common root dir for UF files
parsed=strsplit( '12648|55332|DARW|Thu 02 Aug 00:00:00 2007|28.1133|-80.6542|0.011|DARW/1CUF/2007/0304/UF20070304_102001.PPI.gz', '|', /extract )
;parsed=strsplit( '12648|55332|KMLB|Thu 02 Aug 00:00:00 2007|28.1133|-80.6542|0.011|KMLB/1CUF/2007/0802/070802.1.MELB.4.0035.uf.gz', '|', /extract )
       event_num = long( parsed[0] )
       orbit = parsed[1]
       NXsiteID = parsed[2]    ; NOAA agency siteID
       pg_nominal = parsed[3]
       siteLat = parsed[4]
       siteLon = parsed[5]
       siteElev = parsed[6]    ; required units are km !!!
       origUFName = parsed[7]  ; filename as listed in/on the database/disk,
;      adding the well-known common path to get the fully-qualified file name:
       file_1CUF = in_base_dir + origUFName
       base_1CUF = file_basename(file_1CUF)
       if ( base_1CUF eq 'no_1CUF_file' ) then begin
          print, "No 1CUF file for event = ", event_num, ", skipping."
;          goto,next_file
       endif
;      get the individual file's date string from the file name, along with the TRMM
;      representation of the NEXRAD site ID
       if ( NXsiteID eq 'DARW' ) then begin
          my_yymmdd = strmid( base_1CUF,4,6 )
	  siteID = NXsiteID
       endif else begin
          parsed2 = strsplit( base_1CUF, '.', /extract )
          my_yymmdd = parsed2[0]
          siteID = parsed2[2]      ; TRMM GVS site ID
       endelse
;      convert the Postgres datetime string into REORDER's format
       p3 = strsplit( pg_nominal, ' ', /extract )
       nominal = p3[1] + '-' + p3[2] + '-' + strmid( p3[4],2,3) + ',' + p3[3]
       print, ""
       print, "Gridding ", file_1CUF
       print, event_num,"  ",orbit,"  ",nominal,"  ",siteID,"  ",siteLat, "  ", siteLon

end
