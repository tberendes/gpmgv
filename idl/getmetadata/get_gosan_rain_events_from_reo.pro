pro get_gosan_rain_events_from_reo

; "include" file for PR data constants
@pr_params.inc

; "include" file for PR netCDF grid structs, now that we call read_pr_netcdf()
@grid_nc_structs.inc

mygridstruc={grid_def_meta}
mysitestruc={gv_site_meta}

;##################################

pathgv2 = '/data/netcdf/NEXRAD_REO/allYMD/GVgridsREO*RGSN*'
gvfiles = file_search(pathgv2,COUNT=nf)
haveDist = 0

if nf gt 0 then begin

  ; create and open the OUTPUT file
  ;DATESTAMP = GETENV("RUNDATE")
  metadatafile = "/data/tmp/REO_METADATA.unl"
  GET_LUN, UNLUNIT
  OPENW, UNLUNIT, metadatafile ;, /APPEND

  for fnum = 0, nf-1 do begin
    haveREO = 0
    ncfilegv = gvfiles(fnum)
    cpstatusREO = uncomp_file( ncfilegv, ncfile3 )
    if (cpstatusREO eq 'OK') then begin
       status = 1       ; initialize to FAILED
       event_timeREO=0.0D
       mygrid=mygridstruc
       mysite=mysitestruc
       dbznexREO=fltarr(2)
       status = read_gv_reo_netcdf( ncfile3, dtime=event_timeREO, gridmeta=mygrid, $
           sitemeta=mysite, dbz3d=dbznexREO )
       IF (status NE 0) THEN BEGIN
         print, "ERROR in reading GV REO netCDF file: ", ncfile3
       ENDIF
       haveREO = 1                       ; initialize flag
       command = "rm  " + ncfile3
       spawn, command
    endif else begin
       print, 'Cannot find GVREO netCDF file: ', ncfilegvREO
       print, cpstatusREO
    endelse

    if (haveREO eq 1) then begin
       parsed=strsplit( ncfilegv, '.', /extract )
       siteID = parsed[1]
       ;siteID = mysite.site_id
       orbit = parsed[3]
       siteLat = mysite.site_lat
       siteLong = mysite.site_lon
;       print, siteID, siteLat, siteLong, event_timeREO ;, event_time2
       
       ; Compute a radial distance array of 2-D netCDF grid dimensions
       if (haveDist eq 0) then begin
         NX = mygrid.nx
         NY = mygrid.ny
         gridspacex = mygrid.dx
         gridspacey = mygrid.dy
         xdist = findgen(NX,NY)
         xdist = ((xdist mod FLOAT(NX)) - FLOAT(NX/2)) * gridspacex
         ydist = findgen(NY,NX)
         ydist = ((ydist mod FLOAT(NY)) - FLOAT(NY/2)) * gridspacey
         ydist = TRANSPOSE(ydist)
         dist  = SQRT(xdist*xdist + ydist*ydist) ;/1000.  ; m to km
;print, dist[*,0]
         haveDist = 1
       endif
       
       idxneg = where(dbznexREO lt 0.0, countnoz)
       if (countnoz gt 0) then  dbznexREO[idxneg] = 0.0
       idx100 = where(dist le 100.0,count100)
;       print, count100, " points within 100 km"
       dbz2tally = dbznexREO[idx100]
       idxrain = where(dbz2tally ge 18.0, countrain)
       print, "Site: ",siteID, "  Orbit: ", orbit, "  Time: ",event_timeREO, "  Rainy points = ", countrain
       printf, UNLUNIT, format = '(a0,"|",i0,"|",i0)', siteID, orbit,countrain
    endif
  endfor
endif

FREE_LUN, UNLUNIT
print, ''
print, "Done."

end
