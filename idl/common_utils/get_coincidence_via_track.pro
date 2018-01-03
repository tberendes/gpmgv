; DESCRIPTION
; -----------
; Reads satellite subtrack data from a series of files "GPM_1s_subpts.*.txt"
; as output from extract_daily_predicts.sh, for dates between start_date and
; end_date.  Finds times and distances of nearest satellite approach to the
; ground radar "siteID" located at (siteLat, siteLon).  For those approaches
; within the cutoff distance, writes the date/time and distance metadata to a
; delimited text file.
;
; Output file's data need to be loaded into the 'gpmgv' database.  SQL commands
; to do this are located in the file ~/scripts/load_coincidences_via_track.sql.
; The file name in the \copy command in this file needs to be replaced with the
; site-specific output file name from a run of this function.
;
; PARAMETERS
; ----------
; path        - STRING, directory where the "GPM_1s_subpts.*.txt" files reside.
; start_date  - Starting date to compute site overpasses, YYYYMMDD format
; end_date    - Ending date to compute site overpasses, YYYYMMDD format
; siteID      - STRING, site identifier as defined in 'gpmgv' database
;               (instrument_id in table fixed_instrument_location, or radar_id
;               in gvradar table)
; siteLat     - Latitude of ground radar, deg. N
; siteLon     - Longitude of ground radar, deg. E
; thresh_dist - Maximum allowed distance of ground radar from the orbit track.
; outpath     - STRING, directory where the computed site approach data file
;               "siteID_Predict.txt" will be created, where siteID is the value
;               provided as that parameter.
;
; LIMITATIONS
; -----------
; Code only reads and processes track data for one date's subtracks at a time.
; If a closest approach time is detected at the first time in the date's file
; (first time is within thresh_dist, with increasing distance for next time in
; the file) it is output as a coincident event, even though the actual closest
; approach may have occurred in the times from the preceding date.  If an actual
; closest approach happens at the last time in a date's file, it is not output
; since the algorithm won't know whether to tag it as a closest approach time
; unless we have read the next day's track data.


function get_coincidence_via_track, path, start_date, end_date, siteID, $
                                    siteLat, siteLon, thresh_dist, outpath

lat_thresh = 1.1*(thresh_dist/111.1)
lon_thresh = lat_thresh / cos(!DTOR*siteLat)
dailies=file_search(path+'/GPM_1s_subpts.*.txt', count=nf)
if N_ELEMENTS(outpath) eq 0 then outpath = '/tmp'
outfile = outpath+'/'+siteID+'_Predict.txt'

if nf gt 0 then begin
   dataPR = ''
   nfound=0
   for fnum = 0, nf-1 do begin
      parsed=strsplit(file_basename(dailies[fnum]), '.', /extract)
      date = parsed[1]
      if date lt start_date then continue
      if date gt end_date then break
      nlines = FILE_LINES(dailies[fnum])
;print, dailies[fnum]
      lats=FLTARR(nlines) & lons=lats & times=STRARR(nlines)
      OPENR, lun0, dailies[fnum], ERROR=err, /GET_LUN
      for ilin=0,nlines-1 DO BEGIN 
         READF, lun0, dataPR
         parsedlin = strsplit(dataPR, ',', /extract)
         lats[ilin] = FLOAT(parsedlin[0])
         lons[ilin] = FLOAT(parsedlin[1])
         times[ilin] = dataPR  ;parsedlin[2]
      endfor
      CLOSE, lun0 & FREE_LUN, lun0

      distdir = MAP_2POINTS(lons[0], lats[0], siteLon, siteLat, /METERS)
      last_dist = distdir[0]/1000.
      min_dist = last_dist
      this_dist = last_dist
      tallied=0
      last_data = times[0]
      for ilin=1,nlines-1 DO BEGIN 
         IF abs(lats[ilin]-siteLat) LE lat_thresh THEN BEGIN
           ; check lon threshold (assumes not crossing dateline, +/180. deg)
            IF abs(lons[ilin]-siteLon) LE lon_thresh THEN BEGIN
              ; check true distance against thresh_dist and last_dist
                distdir = MAP_2POINTS(lons[ilin], lats[ilin], siteLon, siteLat, /METERS)
                this_dist = distdir[0]/1000.
                if this_dist LT min_dist then min_dist=this_dist
;print, lats[ilin], lons[ilin], this_dist
            ENDIF ELSE BEGIN
               IF tallied EQ 1 THEN BEGIN
                 ; we were in-range and found a min, now we've gone out-of-range,
                 ; reset for next approach
                  tallied=0
                  min_dist = thresh_dist+1.0
               ENDIF
            ENDELSE
         ENDIF
         IF min_dist LE thresh_dist THEN BEGIN
           ; check whether we have "hit bottom", and if so, write the closest
           ; approach info to file
            IF this_dist GT last_dist and tallied EQ 0 then begin
              ; open the output file if this is the first coincidence event
               IF nfound EQ 0 THEN OPENW, lun1, outfile, /get_lun
              ; grab the time out of the track data and format for database, e.g.
              ; 2014-08-19T23:11:08.000 -> 2014-08-19 23:11:08+00
               parsed=strsplit(last_data, ',', /extract)
               dbtime=strmid(parsed[2],0,10)+' '+strmid(parsed[2],11,8)+'+00'
               printf, lun1, 'GPM|' + siteID + '|' +dbtime + '|' + $
                       STRING(last_dist+0.5, FORMAT='(I0)')
print, 'GPM|' + siteID + '|' +dbtime + '|' + STRING(last_dist+0.5, FORMAT='(I0)')
               tallied = 1
               nfound++
            ENDIF
         ENDIF
         last_dist = this_dist
         last_data = times[ilin]
      endfor
   endfor
endif else begin
   print, "No file matches!"
   nfound = -1
endelse

if nfound gt 0 then begin
   close, lun1
   print, "Output file = ", outfile
endif

return, nfound
end

