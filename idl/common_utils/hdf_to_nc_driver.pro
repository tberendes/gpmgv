;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; hdf_to_nc_driver.pro            Morris/SAIC/GPM_GV     Mar. 2013
;
; DESCRIPTION
; -----------
; Driver for the hdf_to_nc_XXNN() functions.  Sets up user/default parameters
; for the set of TRMM HDF files to be subsetted by variable and written to a
; compressed netCDF file.
;
; PARAMETERS
; ----------
; ncpath          - local directory path to the HDF and netCDF files' location.
;                   Defaults to datadirroot+'/full_orbit' where datadirroot is
;                   determined from the hostname where IDL is running.
;
; products        - array, lists product types/subdirectories to be processed.
;                   Default = [ '2A23', '2A25', '2B31' ]
;
; filefilter      - file pattern which acts as the filter limiting the set of
;                   input files over which the program will iterate.
;                   Default = '*.HDF.Z'
;
; delete_original - Binary option, determines whether or not to delete the
;                   source HDF file after subsetting and writing to netCDF.
;
; HISTORY
; -------
; 03/27/13 Morris, GPM GV, SAIC
; - Created.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

pro delete_hdf, hdf2del, ncfile

   IF FILE_TEST(hdf2del, /REGULAR, /WRITE) EQ 0 THEN BEGIN
      message, "Cannot delete file "+hdf2del, /info
      command = 'ls -al '+hdf2del
      spawn, command
   ENDIF ELSE BEGIN
      IF FILE_TEST(ncfile, /REGULAR) EQ 1 $
      AND FILE_TEST(ncfile, /ZERO_LENGTH) EQ 0 THEN BEGIN
         command = 'rm -v '+hdf2del
         ;spawn, command
         print, "command = '", command, "'"
      ENDIF ELSE BEGIN
         message, "NetCDF file "+ncfile+$
                  " not a regular file or is empty, do not delete HDF file "+ $
                  hdf2del, /info
      ENDELSE
   ENDELSE
END

;===============================================================================

pro hdf_to_nc_driver, NCPATH=ncpath, $
                      PRODUCTS=products, $
                      FILEFILTER=filefilter, $
                      DELETE_ORIGINAL=delete_original


   IF ( N_ELEMENTS(ncpath) NE 1 ) THEN BEGIN
      ; assign default values to keyword parameters
      CASE GETENV('HOSTNAME') OF
         'ds1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data/gpmgv'
         'ws1-gpmgv.gsfc.nasa.gov' : datadirroot = '/data'
         ELSE : BEGIN
                print, "Unknown system ID, setting 'datadirroot' to '~/data'"
                datadirroot = '~/data'
                END
      ENDCASE
      ncpath = datadirroot+'/fullOrbit'
      IF (FILE_TEST(ncpath, /DIRECTORY) EQ 0) THEN BEGIN
            message, ncpath+" not found or not a directory."
      ENDIF ELSE print, "Setting NCPATH to ", ncpath
   ENDIF

   IF (N_ELEMENTS(products) LT 1) THEN BEGIN
      print, "Doing 2A23, 2A25, and 2B31 products, by default."
      products = [ '2A23', '2A25', '2B31' ]
   ENDIF

   IF (N_ELEMENTS(filefilter) NE 1) THEN BEGIN
      print, "Setting filefilter pattern to *.HDF.Z"
      filefilter = '*.HDF.Z'
   ENDIF

   nprod = N_ELEMENTS(products)
   known_products = [ '2A23', '2A25', '2B31' ]
   for iprod = 0, nprod-1 do begin
      IF WHERE(STRPOS(known_products, products[iprod]) GE 0) NE -1 THEN BEGIN
         pathpr = ncpath+'/'+products[iprod]
         IF (FILE_TEST(pathpr, /DIRECTORY) EQ 0) THEN BEGIN
            message, pathpr+" not found or not a directory."
         ENDIF
      ENDIF ELSE message, "Product type "+products[iprod]+" not allowed/known."

      prfiles = file_search(pathpr+'/'+filefilter, COUNT=nf)

      if nf eq 0 then begin
         print, 'No HDF files matching file pattern: ', pathpr+'/'+filefilter
      endif else begin
         for fnum = 0, nf-1 do begin
            ; create the netCDF filename by substituting '.nc' for '.HDF*'
            replaceidx = STRPOS(STRUPCASE(prfiles[fnum]), "HDF")
            IF replaceidx EQ -1 THEN BEGIN
               print, "Can't find/replace 'HDF*' in HDF filename "+prfiles[fnum]
               stop
            ENDIF ELSE file_NCDF = STRMID(prfiles[fnum],0,replaceidx)+"nc"
            print, '' & print, "Reading ", prfiles[fnum]
            print, "Subsetting into ", file_NCDF & print, ''
            CASE products[iprod] OF
               '2A23' : BEGIN
                           ; set flags for the variables we want in the netCDF:
                           ; Read/Copy=1, Skip=0 (or undefined)
                           geolocation = 0
                           rainFlag = 0
                           rainType = 0
                           statusFlag = 1
                           BBheight = 1
                           BBstatus = 1
                           status = hdf_to_nc_2a23( prfiles[fnum], file_NCDF, $
                                      GEOL=geolocation, STATUSFLAG=statusFlag, $
                                      RAINTYPE=rainType, RAINFLAG=rainFlag, $
                                      BBHEIGHT=BBheight, BBSTATUS=BBstatus, $
                                      VERBOSE=verbose )
                           IF status NE 1 THEN BEGIN
                              message, "Failure in hdf_to_nc_2a23().", /info
                              stop
                           ENDIF
                        END ;;
               '2A25' : BEGIN
                           ; set flags for the variables we want in the netCDF
                           dbz_2a25 = 0
                           rain_2a25 = 0
                           surfRain_2a25 = 1
                           geolocation = 1
                           rangeBinNums = 0
                           rainFlag = 1
                           rainType = 1
                           pia = 0
                           scan_time = 0
                           frac_orbit_num = 0
                           status = hdf_to_nc_2a25( prfiles[fnum], file_NCDF, $
                                      GEOL=geolocation, DBZ=dbz_2a25, $
                                      RAIN=rain_2a25, TYPE=rainType, $
                                      RN_FLAG=rainFlag, $
                                      SURFACE_RAIN=surfRain_2a25, $
                                      RANGE_BIN=rangeBinNums, $
                                      PIA=pia, SCAN_TIME=scan_time, $
                                      FRACTIONAL=frac_orbit_num, $
                                      VERBOSE=verbose )
                           IF status NE 1 THEN BEGIN
                              message, "Failure in hdf_to_nc_2a25().", /info
                              stop
                           ENDIF
                        END ;;
               '2B31' : BEGIN
                           ; set flags for the variables we want in the netCDF
                           surfRain_2b31 = 1
                           scan_time = 0
                           frac_orbit_num = 0
                           status = hdf_to_nc_2b31( prfiles[fnum], file_NCDF, $
                                      SURFACE_RAIN_2B31=surfRain_2b31, $
                                      SCAN_TIME=scan_time, $
                                      FRACTIONAL=frac_orbit_num, $
                                      VERBOSE=verbose )
                           IF status NE 1 THEN BEGIN
                              message, "Failure in hdf_to_nc_2b31().", /info
                              stop
                           ENDIF
                        END ;;
                 ELSE : message, "We're lost in the woods.  Product = " + $
                                 products[iprod] ;;
            ENDCASE

            IF (status EQ 1) AND KEYWORD_SET(delete_original) THEN $
               delete_hdf, prfiles[fnum], file_NCDF+'.gz'

         endfor  ; loop over files of a product type
      endelse
   endfor        ; loop over product type

END
