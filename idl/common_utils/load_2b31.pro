;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; ***************************************************************
; * PROGRAM TO LOAD 1B11,2A23,2A25 TRMM DATA FILES              *
; * SEE DOCUMENTATION FOR INSTRUCTIONS                          *
; * S. NESBITT V1.0 11/9/98                                     *
; ***************************************************************
; * Modifications by David B. Wolff, NASA/GSFC/613.1, SSAI      *
; ***************************************************************
; * MODIFIED:  August 2008 by Bob Morris, GPM GV (SAIC)         *
; *  - Changed how filen is parsed to get the YYMMDD part from  *
; *    the individual file name parts.  This is due to how the  *
; *    modified function uncomp_file prepends to the file name  *
; *    when making a copy, to make sure the original file will  *
; *    not be deleted inadvertently.                            *
; *  - Added scanTime to the variables in 'data' structure.     *
; *  December 2008 by Bob Morris, GPM GV (SAIC)                 *
; *  - Changed how field '2B31' is looked for in the filename,  *
; *    now use STRPOS rather than an exact match.  GPM_KMA      *
; *    subset has different name convention, not *.2B31.*       *
; *  Oct. 2010 by Bob Morris, GPM GV (SAIC)                     *
; *  - Fixed parsing of YYMMDD date in file name.               *
; ***************************************************************
; * SYNOPSIS:
; * flag = load_2b31('data/KWAJ/2B31/1999/2B31_CSI.990415.7944.KWAJ.6.HDF.Z',s)
; *
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

    function load_2b31,filen,data

; *** Parse file name for some info
;
    filebase = file_basename(filen)
    a = strsplit(filebase,'.',/extract)
    type = a(0)
    orbit = a(2)
    site = a(3)
    ver  = a(4)
;
; *** Open the file
;
    if HDF_IsHDF (filen) then begin
	fileid=hdf_open(filen,/read)
        if ( fileid eq -1 ) then begin
           print, "In load_2b31.pro, error opening hdf file: ", filen
	   flag = 'Bad HDF File!'
	   return, flag
        endif
    endif else begin
        print, "In load_2b31.pro, tried to open non-hdf file: ", filen
	flag = 'Not HDF File!'
	return, flag
    endelse
;
; *** READ THE VDATA TO GET THE SCAN TIMES
;
	vdataid=hdf_vd_getid(fileid,-1)
	vdname=hdf_vd_attach(fileid,vdataid)
    HDF_VD_GET,vdname,NFIELDS=n,count=nrecs
    if(nrecs eq 0) then begin
        hdf_vd_detach,vdname
        hdf_close,fileid
        flag = 'Empty Granule found!'
        print,flag
        return,flag
    endif
;
; *** Get the number of SDSs in the file
;
    sdsfileid = hdf_sd_start(filen,/read)

    hdf_sd_fileinfo,sdsfileid,numsds,ngatt
    names = strarr( numsds )
    ndims = lonarr( numsds )
    dtype = strarr(numsds)
    
    for i = 0, numsds - 1 do begin
        sds_id = hdf_sd_select(sdsfileid, i )
        hdf_sd_getinfo, sds_id, name = na, ndim = nd,type= typ
        names( i ) = na 
        ndims( i ) = nd
        dtype(i) = typ  
    endfor

    if numsds gt 0 then begin
;        print,"     Label       Dims   Type    Min   Max"
;        print,"---------------- ---- -------- ----- -----"
        for i=0,numsds-1 do begin
;            print,names(i),ndims(i),dtype(i),FORMAT='(A14,"   ",I4," ",A8," ")'
        endfor
    endif

;
; *** Load the VData
;
    vdataid=hdf_vd_find(fileid,'scan_time')
    vdname=hdf_vd_attach(fileid,vdataid)
    numscans=hdf_vd_read(vdname,scanTime,field='scanTime')

; Find the Scan status Vdata
  vdata_ID = hdf_vd_find(fileid,'pr_scan_status')

; Attach to this Vdata
  vdata_H = hdf_vd_attach(fileid,vdata_ID)

; Get the Vdata stats
  hdf_vd_get,vdata_H,name=name,fields=raw_field

; Separate the fields
  fields = str_sep(raw_field,',')

; Read the Vdata, returns the number of records
; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)
; IDL will issue a warning to remind you there are mixed data types in
; the array
  nscan = hdf_vd_read(vdata_h,data)
; Could have just read in the fractional orbit number with the
; fields keyword but this shows you how to extract the data from the 
; full record BYTE array.

; Make up an array for the fractional orbit number
  frac_orbit_num = fltarr(nscan)

; Loop over the records and pull out the fractional orbit number   
  for i = 0,nscan-1 do begin
; We know that the frac_orbit_number starts at position 11 in the byte array
    frac_orbit_num(i) = float(data(*,i),11)
  endfor
;
; *** 2B31 scan time is second of the day. Get year, month and day
; *** from filename.
;
    s=size(scanTime)
    yy=strarr(s[1]) & mo=yy & dd=yy & hh=yy & mm=yy & ss=yy
    parsed_out=str_sep(filen,'.')
; *** take into account that uncomp_file() adds a unique prefix to the original
;     file name, so test where the '2B31' filename segment is located when
;     grabbing the YYMMDD part of the filename, to store in the variable datestr
    datestr = parsed_out[1]
    if STRPOS( parsed_out[1], '2B31' ) NE -1 then datestr = parsed_out[2]
    yearstr = strmid(datestr,0,2)
    for i=0,s[1]-1 do begin
        if(FIX(yearstr) gt 50) then begin
            yy[i]=strcompress(string('19'+yearstr),/remove_all)
        endif else begin
            yy[i]=strcompress(string('20'+yearstr),/remove_all)
        endelse
        mo[i]=strcompress(string(strmid(datestr,2,2)),/remove_all)
        dd[i]=strcompress(string(strmid(datestr,4,2)),/remove_all)
    endfor
;
; *** Get julday
;
    jday = get_julday(yy(0),mo(0),dd(0))
;
; *** Get time from second of the day
;
    flag = get_time_from_sotd(scantime,hh,mm,ss)
;
; *** Load the SDS data
;
    sdsfileid = hdf_sd_start(filen,/read)

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'geolocation'))
    hdf_sd_getdata,sds_id,geo

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'dHat'))
    hdf_sd_getdata,sds_id,dHat

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'sigmaDHat'))
    hdf_sd_getdata,sds_id,sigmadhat

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'rHat'))
    hdf_sd_getdata,sds_id,rhat

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'sigmaRHat'))
    hdf_sd_getdata,sds_id,sigmarhat

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'rrSurf'))
    hdf_sd_getdata,sds_id,rrsurf

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'sigmaRRsurf'))
    hdf_sd_getdata,sds_id,sigmarrsurf

    sds_id = hdf_sd_select(sdsfileid,hdf_sd_nametoindex(sdsfileid,'latentHeatHH'))
    hdf_sd_getdata,sds_id,latentheathh

;        
; *** Calculate the 2A12 stuff
;        
    dim=size(geo)
    rays=dim[2]
    scans=dim[3]

    lat = reform(geo[0,*,*])
    lon = reform(geo[1,*,*])
;
; *** These are place holders that will be filled in the main line
; *** routines upon return.
;
    range = fltarr(n_elements(lat(*,0)),n_elements(lat(0,*)))
    gv_bounds = {site: site, lat:0.0, lon: 0.0, wbc: 0.0, ebc: 0.0, sbc: 0.0, nbc: 0.0}

;
; *** Fill the structure
;
    data={site: site,                 $
          gv_bounds: gv_bounds,       $
          type: type,                 $
          orbit: orbit,               $
          version: ver,               $
          scans: scans,               $
          rays: rays,	              $ 
          range: range,               $
          year: yy,                   $
          month: mo,                  $
          day: dd,                    $
          hour: hh,                   $
          minute: mm,                 $
          second: ss,                 $
          jday: jday,                 $
          fractional: frac_orbit_num, $
          lon: lon,                   $
          lat: lat,                   $
          rain: rrsurf,               $
          scan_time: scanTime,        $
          latentheat: latentheatHH    $
         }
;    help,/str,data
;
; *** Close HDF file
;    
    hdf_sd_endaccess,sds_id
    hdf_sd_end,sdsfileid
    hdf_close,fileid


    flag = 'OK'
    return,flag
end
