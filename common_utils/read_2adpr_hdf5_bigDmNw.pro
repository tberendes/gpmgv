;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_2adpr_hdf5.pro         Bob Morris, GPM GV/SAIC   June 2013
;
; DESCRIPTION
; -----------
; Given the full pathname to a 2ADPR HDF5 file, reads and parses the FileHeader
; metadata attributes and selected data groups and their included datasets.
; Assembles and returns a structure mimicking the HDF file organization,
; containing all the data read and/or parsed.  Sub-structures for large-array
; datasets and HDF groups containing large-array datasets (e.g., 'MS/VER'
; group) are defined as pointer references-to-structures in the output
; structure 'outstruc'.  Those datasets directly below the swath levels
; (Latitude, Longitude) are bundled into a structure called "DATASETS" within
; the HS, MS and NS structures.
;
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; file      -- Full pathname of the HDF5 file to be read
; debug     -- Binary keyword parameter, controls output of diagnostic messages.
;              Default = suppress messages.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
; scan2read -- Limits the swath groups (scan types) read to only the group
;              specified by the keyword value.  Keyword is ignored if read_all
;              is set.
;
; HISTORY
; -------
; 06/04/13  Morris/GPM GV/SAIC
; - Created.
; 06/12/13  Morris/GPM GV/SAIC
; - Added READ_ALL option to pare down the datasets read by default.
; 06/18/13  Morris/GPM GV/SAIC
; - Added SCAN keyword option to limit the swath groups read to only one swath.
; 01/08/14  Morris/GPM GV/SAIC
; - Added calls to get_dpr_navigation_group and get_dpr_experimental_group, and
;   added structures containing these groups' data to the returned structure.
;   
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_2adpr_hdf5_bigDmNw, file, DEBUG=debug, READ_ALL=read_all, SCAN=scan2read

   outstruc = -1

   all = KEYWORD_SET(read_all)
   verbose1 = KEYWORD_SET(debug)

   IF all NE 1b AND N_ELEMENTS(scan2read) EQ 1 THEN BEGIN
      SWITCH STRUPCASE(scan2read) OF
         'HS' :
         'MS' :
         'NS' : BEGIN
                  onescan = STRUPCASE(scan2read)
                  break
                END
         ELSE : message, "Illegal value '" + scan2read + $
                         "' for SCAN keyword, must be 'HS', 'MS' or 'NS'"
      ENDSWITCH
   ENDIF ELSE IF N_ELEMENTS(scan2read) GT 1 THEN $
      message, "Parameter value for SCAN keyword is not a scalar string."

   if n_elements(file) eq 0 then begin
      filters = ['2A*DPR*.HDF5*']
      file = dialog_pickfile(FILTER=filters, $
          TITLE='Select 2A-DPR file to read', $
          PATH='/data/gpmgv/orbit_subset/GPM/DPR/2ADPR/V05A/CONUS/2014')
      IF (file EQ '') THEN GOTO, userQuit
   endif

   if (not H5F_IS_HDF5(file)) then $
       MESSAGE, '"'+file+'" is not a valid HDF5 file.' $
   else print, "Processing file: ", file
  
   ; Open file
   file_id = h5f_open(file)
   group_id=h5g_open(file_id, '/')

   ; get value for the FileHeader attribute, located at the top level
   fileHeaderID = h5a_open_name(group_id, 'FileHeader')
   ppsFileHeaderStruc = h5a_read(fileHeaderID)
   ; extract the individual file header values from the formatted string
   filestruc=parse_file_header_group(ppsFileHeaderStruc)
   h5a_close, fileHeaderID
   IF (verbose1) THEN HELP, filestruc
   prodname=filestruc.ALGORITHMID

   IF prodname NE '2ADPR' THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Illegal product type '" + prodname + "', must be '2ADPR'"
   ENDIF

   ; define the swath groups according to product type
   snames=['HS', 'MS', 'NS']   ; prefixes used in DPR products
   IF filestruc.NUMBEROFSWATHS NE N_ELEMENTS(snames) THEN BEGIN
      h5g_close, group_id
      h5f_close, file_id
      message, "Expect 3 swaths in product "+prodname+", have " + $
               STRING(filestruc.NUMBEROFSWATHS, FORMAT='(I0)')
   ENDIF

   ; get the data variables for the swath groups
   for isw = 0, filestruc.NUMBEROFSWATHS-1 do begin
      sname=snames[isw]

      IF N_ELEMENTS(onescan) NE 0 THEN BEGIN
         IF STRMATCH(onescan, sname) EQ 0b THEN BEGIN
            ; this isn't the scan to be read, we skip it and define empty struct
            message, "Skipping swath "+sname, /INFO
            CASE sname OF
               'HS' : HS = { Swath : sname+": UNREAD" }
               'MS' : MS = { Swath : sname+": UNREAD" }
               'NS' : NS = { Swath : sname+": UNREAD" }
            ENDCASE
            continue
         ENDIF
      ENDIF

      print, "" & print, "Swath ",sname,":"
      prodgroup=prodname+'__'+sname      ; label info for data structures
      ; get the group ID for this swath
      sw_group_id = h5g_open(group_id, sname)

      ; get the SwathHeader for this swath
      swathHeaderID = h5a_open_name(sw_group_id, sname+'_SwathHeader')
      ppsSwathHeader = h5a_read(swathHeaderID)
      ; extract the individual swath header values from the formatted string
      swathstruc = parse_swath_header_group(ppsSwathHeader)
      h5a_close, swathHeaderID
      IF (verbose1) THEN help, swathstruc

      ; get the ScanTime structure for this swath
      ptr_scantimes = ptr_new(/allocate_heap)
      *ptr_scantimes = get_scantime_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scantimes

      ; get the scanStatus structure for this swath
      ptr_scstatus = ptr_new(/allocate_heap)
      *ptr_scstatus = get_dpr_scanstatus_group(sw_group_id, prodgroup)
      IF (verbose1) THEN help, *ptr_scstatus

      ; get the swath-group-level datasets, put into a structure
      latvarid = h5d_open(sw_group_id, 'Latitude')
      lonvarid = h5d_open(sw_group_id, 'Longitude')
      ptr_datasets = ptr_new(/allocate_heap)

      *ptr_datasets = { source    : prodgroup, $
                        latitude  : h5d_read(latvarid), $
                        longitude : h5d_read(lonvarid) }

      h5d_close, latvarid
      h5d_close, lonvarid
      IF (verbose1) THEN help, *ptr_datasets

      ; get the navigation structure for this swath
      ptr_nav = ptr_new(/allocate_heap)
      *ptr_nav = get_dpr_navigation_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_nav

      ; get the Experimental structure for this swath
      ptr_exp = ptr_new(/allocate_heap)
      *ptr_exp = get_dpr_experimental_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_exp

      ; get the CSF structure for this swath
      ptr_csf = ptr_new(/allocate_heap)
      *ptr_csf = get_dpr_csf_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_csf

      ; get the DSD structure for this swath
      ptr_dsd = ptr_new(/allocate_heap)
      *ptr_dsd = get_dpr_dsd_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_dsd

      ; get the FLG structure for this swath
      ptr_flg = ptr_new(/allocate_heap)
      *ptr_flg = get_dpr_flg_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_flg

      ; get the PRE structure for this swath
      ptr_pre = ptr_new(/allocate_heap)
      *ptr_pre = get_dpr_pre_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_pre

      ; get the SLV structure for this swath
      ptr_slv = ptr_new(/allocate_heap)
      *ptr_slv = get_dpr_slv_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_slv

      ; get the SRT structure for this swath
      ptr_srt = ptr_new(/allocate_heap)
      *ptr_srt = get_dpr_srt_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_srt

      ; get the VER structure for this swath
      ptr_ver = ptr_new(/allocate_heap)
      *ptr_ver = get_dpr_ver_group(sw_group_id, prodgroup, READ_ALL=all)
      IF (verbose1) THEN help, *ptr_ver

      h5g_close, sw_group_id

      CASE sname OF
         'HS' : BEGIN
                  HS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'MS' : BEGIN
                  MS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         'NS' : BEGIN
                  NS = { Swath : sname, $
                         SwathHeader : swathstruc, $
                         ptr_ScanTime : ptr_scantimes, $
                         ptr_scstatus : ptr_scstatus, $
                         ptr_navigation : ptr_nav, $
                         ptr_Experimental : ptr_exp, $
                         ptr_csf : ptr_csf, $
                         ptr_dsd : ptr_dsd, $
                         ptr_flg : ptr_flg, $
                         ptr_pre : ptr_pre, $
                         ptr_slv : ptr_slv, $
                         ptr_srt : ptr_srt, $
                         ptr_ver : ptr_ver, $
                         ptr_datasets : ptr_datasets }
                END
         ELSE : message, 'What the?!!'
       ENDCASE

   endfor

   outStruc = { FileHeader:filestruc, HS:HS, MS:MS, NS:NS }
   h5g_close, group_id
   h5f_close, file_id

   ptr_swath=outStruc.NS

   IF PTR_VALID(ptr_swath.PTR_SLV) THEN BEGIN
      dbz_corr = (*ptr_swath.PTR_SLV).ZFACTORCORRECTED
      rain_corr = (*ptr_swath.PTR_SLV).PRECIPRATE
      surfRain_corr = (*ptr_swath.PTR_SLV).PRECIPRATEESURFACE
      piaFinal = (*ptr_swath.PTR_SLV).piaFinal
      epsilon = (*ptr_swath.PTR_SLV).EPSILON
      ; - if there is no paramDSD its structure element is the string "UNDEFINED"
      type_paramdsd = SIZE( (*ptr_swath.PTR_SLV).PARAMDSD, /TYPE )
      IF type_paramdsd EQ 7 THEN BEGIN
         have_paramdsd = 0
      ENDIF ELSE BEGIN
         have_paramdsd = 1
         dpr_Nw = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[0,*,*,*] )/10.
         dpr_Dm = REFORM( (*ptr_swath.PTR_SLV).PARAMDSD[1,*,*,*] )
         print, "Max Dm: ", max(dpr_Dm)
        ; grab samples whose rain rates exceed 20 mm/h
         idxflood=where(rain_corr GE 20.0, nflood)
         if nflood gt 0 then begin
            zflood = dbz_corr[idxflood]
            dmflood = dpr_Dm[idxflood]
            nwflood = dpr_Nw[idxflood]
            rrflood = rain_corr[idxflood]
           ; histogram these values
            zhist = histogram(zflood, min=15.0, max=65.0, binsize = 1.0, locations = zhiststart)
            dmhist = histogram(dmflood, min=3.5, max=6.0, binsize = 0.1, locations = dmhiststart)
            nwhist = histogram(nwflood, min=0.0, max=5.0, binsize = 0.1, locations = nwhiststart)
            device, decomposed = 0
   ; Set up color table
   ;
   common colors, r_orig, g_orig, b_orig, r_curr, g_curr, b_curr ;load color table
            LOADCT, 2
   ncolor=255
   red=bytarr(256) & green=bytarr(256) & blue=bytarr(256)
   red=r_curr & green=g_curr & blue=b_curr
   red(0)=255 & green(0)=255 & blue(0)=255
   red(1)=115 & green(1)=115 & blue(1)=115  ; gray for GR
   red(ncolor)=0 & green(ncolor)=0 & blue(ncolor)=0 
   tvlct,red,green,blue
            Window, xsize=1050, ysize=350, TITLE = 'DPR Z, Dm, and Nw for RR >= 20mm/h -- '+FILE_BASENAME(file)
            !P.Multi=[0,3,1,0,0]
            PLOT, zhiststart, zhist, color=200, TITLE = 'Z', xtitle='dBZ', ytitle='COUNT', CHARSIZE=2, background=0
            PLOT, dmhiststart, dmhist, color=150, TITLE = 'Dm', xtitle='mm', ytitle='COUNT', CHARSIZE=2
            PLOT, nwhiststart, nwhist, color=100, TITLE = 'Nw', xtitle='log10(Nw)', ytitle='COUNT', CHARSIZE=2
;    'DMRRP' : BEGIN
                ; accumulate 2-D histogram of GR and DPR Dm vs. RR
                ; - Need to have about the same # bins in both RR and Dm
                ;   i.e., (binmax-binmin)/BINSPAN

                ; RR histo parms
                    trim = 0
                    binmin1 = 20.0 & binmax1 = 60.0
                    BINSPAN1 = 1.0
                ; Dm histo parms
                 binmin2 = 0.0 & binmax2 = 4.0 & BINSPAN2 = 0.1
;                 BREAK
;              END
                    scat_Y = dmflood
                    scat_X = rrflood

  ; Check whether the arrays to be histogrammed both have in-range values,
  ; otherwise just skip trying to histogram out-of-range data
   idx_XY = WHERE(scat_X GE binmin1 AND scat_X LE binmax1 $
              AND scat_Y GE binmin2 AND scat_Y LE binmax2, count_XY)
   IF (count_XY GT 0) THEN BEGIN

         zhist2d = HIST_2D( scat_X, scat_Y, MIN1=binmin1, $
                            MIN2=binmin2, MAX1=binmax1, MAX2=binmax2, $
                            BIN1=BINSPAN1, BIN2=BINSPAN2 )
         minprz = MIN(scat_Y)
         numpts = TOTAL(zhist2d)
                   SCAT_DATA = "Any/All Samples, RR>=30.0mm/h"
                   xticknames=STRING(INDGEN(11)*4+20.0, FORMAT='(I0)')
                   trim = 0    ; show low-percentage outliers
              yticknames=['0.0','0.5','1.0','1.5','2.0','2.5','3.0','3.5','4.0']
              xmajor=N_ELEMENTS(xticknames) & ymajor=N_ELEMENTS(yticknames)
              titleLine1 = " Dm vs. RR Scatter"
              pngpre="DPR_RR_GE_30_Dm_vs_RR_Scatter"
              xunits='(mm/h)'
              yunits='mm'
              xtitle= ' RR'+ xunits
              ytitle= ' Dm (' + yunits + ')'
   sh = SIZE(zhist2d, /DIMENSIONS)
;PRINT, "sh: ", SH
  ; last bin in 2-d histogram only contains values = MAX, cut these
  ; out of the array
   zhist2d = zhist2d[0:sh[0]-2,0:sh[1]-2]
         nSamp = TOTAL(zhist2d)

  ; convert counts to percent of total if show_pct is set
   show_pct=1
   IF KEYWORD_SET(show_pct) THEN BEGIN
     ; convert counts to percent of total
      zhist2d = (zhist2d/DOUBLE(nSamp))*100.0D
      IF trim EQ 1 THEN pct2blank = 0.1 ELSE pct2blank = 0.025
     ; set values below pct2blank to 0%
      histLE5 = WHERE(zhist2d LT pct2blank, countLT5)
      IF countLT5 GT 0 THEN zhist2d[histLE5] = 0.0D

     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
   ENDIF ELSE BEGIN
     ; SCALE THE HISTOGRAM COUNTS TO 0-255 IMAGE BYTE VALUES
      histImg = BYTSCL(zhist2D)
     ; set non-zero Histo bins that are bytescaled to 0 to a small non-zero value
      idxnotzero = WHERE(histImg EQ 0b AND zhist2D GT 0, nnotzero)
      IF nnotzero GT 0 THEN histImg[idxnotzero] = 1b
   ENDELSE
  ; resize the image array to something like 150 pixels if it is small
   sh = SIZE(histImg, /DIMENSIONS)
;PRINT, "sh: ", SH
   IF MAX(sh) LT 125 THEN BEGIN
      scale = 150/MAX(sh) + 1
      sh2 = sh*scale
;PRINT, "sh2: ", SH2
      histImg = REBIN(histImg, sh2[0], sh2[1], /SAMPLE)
   ENDIF
   winsiz = SIZE( histImg, /DIMENSIONS )
   histImg = CONGRID(histImg, winsiz[0]*4, winsiz[1]*4)
   winsiz = SIZE( histImg, /DIMENSIONS )
;print, 'winsiz: ', winsiz
;   rgb=COLORTABLE(33)     ; not available for IDL 8.1, use LOADCT calls
   LOADCT, 33, RGB=rgb, /SILENT   ; gets the values w/o loading the color table
   LOADCT, 33, /SILENT            ; - so call again to load the color table
   rgb[0,*]=255   ; set zero count color to White background
   imTITLE = "DPR RR vs. Dm Scatter for RR>=30.0 mm/h"

   im=image(histImg, axis_style=2, xmajor=xmajor, ymajor=ymajor, $
            xminor=4, yminor=4, RGB_TABLE=rgb, BUFFER=buffer, $
            TITLE = imTITLE )
   im.xtickname=xticknames
   im.ytickname=yticknames
   im.xtitle= xtitle
   im.ytitle= ytitle
   im.Title.Font_Size = 10
  ; define the parameters for a color bar with 9 tick levels labeled
   ticnms = STRARR(256)
   ticlocs = INDGEN(9)*256/8
   ticInterval = MAX(zhist2d)/8.0
   IF KEYWORD_SET(show_pct) THEN BEGIN
      ticnames = STRING(indgen(9)*ticInterval, FORMAT='(F0.1)' )
      ticID = "% of samples"
   ENDIF ELSE BEGIN
      ticnames = STRING( FIX(indgen(9)*ticInterval), FORMAT='(I0)' )
      ticID = "# samples"
   ENDELSE
   ticnms[ticlocs] = ticnames
   cbar=colorbar(target=im, orientation=1, position=[0.95, 0.2, 0.98, 0.75], $
                 TICKVALUES=ticlocs, TICKNAME=ticnms, TITLE=ticID)
ENDIF
stop
im.close
wdelete
         endif else print, "No bins with RR of 30 mm/h."
      ENDELSE
   ENDIF ELSE message, "Invalid pointer to PTR_SLV."


userQuit:
free_ptrs_in_struct, outstruc
return, outstruc
end
