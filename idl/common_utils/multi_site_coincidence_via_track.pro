; DESCRIPTION
; -----------
; Calls the utility function get_coincidence_via_track() in a loop over a list
; of ground radar sites and locations provided in a delimited text file.
; Reads satellite subtrack data from a series of files "GPM_1s_subpts.*.txt"
; as output from extract_daily_predicts.sh, for dates between start_date and
; end_date.  Finds times and distances of nearest satellite approach to each
; ground radar "siteID" located at (siteLat, siteLon).  For those approaches
; within the cutoff distance, writes the date/time and distance metadata to a
; delimited text file, one new file per site ID to process.
;
; See the prologue of get_coincidence_via_track.pro for details about loading
; the computed coincidence data to the 'gpmgv' database.
;
; PARAMETERS
; ----------
; path        - STRING, directory where the "GPM_1s_subpts.*.txt" files reside.
; start_date  - Starting date to compute site overpasses, YYYYMMDD format
; end_date    - Ending date to compute site overpasses, YYYYMMDD format
; sitefile    - STRING, a file listing the site identifier, Latitude (deg. N),
;               and Longitude (deg. E) of the ground radar(s) whose coincidences
;               are to be calculated, in a '|' delimited format.  For example:
;
;               KLWX|38.9753|-77.4778
;               KMLB|28.1133|-80.6542
;
; thresh_dist - Maximum allowed distance of ground radar from the orbit track.
; outpath     - STRING, directory where the computed site approach data file(s)
;               "siteID_Predict.txt" will be created, where siteID is the site
;               identifier value(s) provided in the site file.
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


pro multi_site_coincidence_via_track, path, start_date, end_date, sitefile, $
                                      thresh_dist, outpath

; check for the existence of sitefile
fileInfo = FILE_INFO( sitefile )
IF fileInfo.REGULAR THEN BEGIN
  ; get a count of lines in the file
   nsites = FILE_LINES( sitefile )
   IF nsites EQ 0 THEN message, "Empty sitefile: "+sitefile
ENDIF ELSE message, "File "+sitefile+" does not exist."

if N_ELEMENTS(outpath) eq 0 then outpath = '/tmp'

; check for the existence of daily subtrack files in 'path'
dailies=file_search(path+'/GPM_1s_subpts.*.txt', count=nf)

if nf gt 0 then begin
  ; open and process sitefile, and generate the coincidence data for the site
   OPENR, lun0, sitefile, ERROR=err, /GET_LUN

   WHILE NOT (EOF(lun0)) DO BEGIN 
     ; initialize the variable into which file records are read as strings
      dataGR = ''
     ; - read the '|'-delimited input file record into the string:
      READF, lun0, dataGR
      parsed=STRSPLIT( dataGR, '|', /extract )
      IF N_ELEMENTS(parsed) NE 3 THEN BEGIN
         message, "Incorrect line in control file: "+dataGR
      ENDIF
      siteID = STRTRIM(parsed[0],2)
      siteLat = FLOAT(parsed[1])
      siteLon = FLOAT(parsed[2])
      nevents = get_coincidence_via_track( path, start_date, end_date, siteID, $
                                           siteLat, siteLon, thresh_dist, outpath )
      print, ""
      print, STRING(nevents, FORMAT='(I0)'), " overpasses found for ", siteID
   ENDWHILE
   CLOSE, lun0
endif else begin
   print, "No GPM_1s_subpts files under "+path+"!"
endelse

END


