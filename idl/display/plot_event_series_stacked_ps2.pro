;+
; Copyright ¬© 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_event_series.pro
;
; This procedure plots average site reflectivity bias for each site over time.
; Each site is plotted in a different plot window. This version generates two plots
; for each station, with a separate line style. The plot with unadjusted GV Z is
; solid, and the plot with S-band adjusted to KU-band is plotted in dashed.
; The input parameter 'file' must be a two-element array of strings, with the
; file with the unadjusted GV biases in the first string, and the file with the
; GV bias computed with adjusted GV Z in the second file.
;
; Output is to a Postscript file whose name is internally generated.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO plot_event_series_stacked_ps2, file, NSMOOTH=nsmooth
On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

station_names = ['KAMX','KBMX','KBRO','KBYX','KCLX','KCRP','KDGX','KEVX',$
                 'KFWS','KGRK','KHGX','KHTX','KJAX','KJGX','KLCH','KLIX',$
                 'KMLB','KMOB','KSHV','KTBW','KTLH','RMOR']
;station_names = ['KHTX','RMOR']
other_station_names = STRARR(N_ELEMENTS(station_names))
; all stations in the input file that will be plotted = 24 stations
nstations = N_ELEMENTS( station_names )

a_line = ' '

; generate the filename for postscript output
dir_name = '/data/tmp'
out_file = '/event_plot_'
timedate =  SYSTIME(0)
timedate = STRMID(timedate,4,STRLEN(timedate)) ; time & date will be added to
STRPUT, timedate, 'h', 6                       ; the output file name
STRPUT, timedate, 'm', 9
STRPUT, timedate, 's', 12
STRPUT, timedate, 'y', 15
timedate = STRCOMPRESS(timedate, /remove_all)  ; remove all blanks

 entry_device = !d.name
 SET_PLOT, 'PS'
 DEVICE, /portrait, FILENAME=dir_name + out_file + timedate + '.ps', COLOR=1, BITS_PER_PIXEL=8, $
         xsize=7, ysize=9.5, xoffset=0.75, yoffset=0.75, /inches
; !P.COLOR=0 ; make the title and axis annotation black
; !X.THICK=4 ; make the ticks thicker
; !Y.THICK=4 ; ditto
 !P.FONT=0 ; use the device fonts supplied by postscript

PRINT, ' '
PRINT, 'reading from files:'
PRINT, '   ', file[0], "  :  ",file[1]

; filename of the input data file -- see query in dbzdiff_stats_by_dist.sql for creation

OPENR, r_lun, file[0], /GET_LUN, ERROR=err
PRINT, 'error code', err
OPENR, r_lun2, file[1], /GET_LUN, ERROR=err
PRINT, 'error code', err

event_ID   = ' '
site_name  = ' '
event_date = ' '
num_events = 0
total_stations = 0
yrstart = 3000
yrend = 0
event_data = ''
WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through all records*****
  READF, r_lun, event_data
  num_events = num_events+1
  parsed = strsplit( event_data, '|', /extract )
  event_date = parsed[1]
  i_year  = FIX(STRMID(event_date,0,4))
  yrstart = yrstart < i_year             ; earliest year in file
  yrend = yrend > i_year                 ; latest year in file
ENDWHILE
PRINT, 'total number of events = ', num_events

FREE_LUN, r_lun

OPENR, r_lun, file[0], /GET_LUN, ERROR=err

site_arr   = STRARR(num_events)
x_date_arr = FLTARR(num_events)
y_mean_arr = FLTARR(num_events)
y_mean_arr2 = FLTARR(num_events)
num_samples_arr = LONARR(num_events)
x_range    = FLTARR(2) ; index0 is min index1 is max
y_range    = FLTARR (2) ; index0 is min index1 is max
FOR i=1,num_events DO BEGIN
  READF, r_lun, event_data
  parsed = strsplit( event_data, '|', /extract )
   site_name = parsed[0]
   event_date = parsed[1]
   e_mean = float(parsed[2])
   num_samples = long( parsed[3] )
  READF, r_lun2, event_data
  parsed = strsplit( event_data, '|', /extract )
   e_mean2 = float(parsed[2])

  i_month = FIX(STRMID(event_date,5,2))
  i_day   = FIX(STRMID(event_date,8,2))
  i_year  = FIX(STRMID(event_date,0,4))
;  IF (i_year LT 50) THEN i_year=i_year+2000 ELSE i_year=i_year+1990

  num_samples_arr[i-1] = num_samples

  yr_to_date = 0
  FOR j=1,i_month-1 DO BEGIN
    IF (j EQ 1) OR (j EQ 3) OR (j EQ 5) OR (j EQ 7) OR $
       (j EQ 8) OR (j EQ 10) OR (j EQ 12) $
       THEN yr_to_date = yr_to_date + 31
    IF (j EQ 4) OR (j EQ 6) OR (j EQ 9) OR (j EQ 11) $
       THEN yr_to_date = yr_to_date + 30
    IF j EQ 2 THEN BEGIN
       IF ((i_year MOD 4) EQ 0) THEN $
         yr_to_date = yr_to_date + 29 ELSE $
         yr_to_date = yr_to_date + 28
    ENDIF ; february case
  ENDFOR ; calculate year to date

  site_arr[i-1]   = site_name  
  y_mean_arr[i-1] = e_mean
  y_mean_arr2[i-1] = e_mean2
  x_date_arr[i-1] = yr_to_date + i_day
  IF ((i_year MOD 4) EQ 0) THEN day_fact=366 ELSE day_fact=365

; ******************************************************************
; ** this logic computes days since 1 Jan of 1st year in dataset ***
; ******************************************************************
  x_date_arr[i-1] = x_date_arr[i-1] + (i_year-yrstart) * day_fact
;  print, i_year, i_month, i_day, yr_to_date + i_day, x_date_arr[i-1]

  IF (i EQ 1) THEN BEGIN ; find the bounds for the plot axes
    x_range[0] = x_date_arr[i-1]
    y_range[0] = y_mean_arr[i-1] < y_mean_arr2[i-1]
    x_range[1] = x_date_arr[i-1]
    y_range[1] = y_mean_arr[i-1] > y_mean_arr2[i-1]
  ENDIF ELSE BEGIN
    IF (x_date_arr[i-1] GT x_range[1]) THEN x_range[1] = x_date_arr[i-1]
    IF (x_date_arr[i-1] LT x_range[0]) THEN x_range[0] = x_date_arr[i-1]
    IF (y_mean_arr[i-1] GT y_range[1]) THEN y_range[1] = y_mean_arr[i-1]
    IF (y_mean_arr[i-1] LT y_range[0]) THEN y_range[0] = y_mean_arr[i-1]
    IF (y_mean_arr2[i-1] GT y_range[1]) THEN y_range[1] = y_mean_arr2[i-1]
    IF (y_mean_arr2[i-1] LT y_range[0]) THEN y_range[0] = y_mean_arr2[i-1]
  ENDELSE
ENDFOR

FREE_LUN, r_lun
FREE_LUN, r_lun2

; expand the plot boundaries by 2.5%
x_range[0] = FIX((x_range[0] - 0.025 * (x_range[1] - x_range[0]))*10.)/10
x_range[1] = FIX((x_range[1] + 0.025 * (x_range[1] - x_range[0]))*10.)/10
y_range[0] = y_range[0] - 0.025 * (y_range[1] - y_range[0])
y_range[1] = y_range[1] + 0.025 * (y_range[1] - y_range[0])

;device, decomposed=0, RETAIN=2
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN addtext=', unsmoothed.' ELSE addtext=', smoothed.'

; generate the plot frames, in black
;window, 0, xsize=700, ysize=850 ;, TITLE='Sites with all cases within 3 dBZ bias to PR'+addtext

rgb24=[ $
[255,255,255], $  ;white
;[105,105,105], $  ;dim gray
[90,90,90], $  ;black
[211,211,211], $  ;light gray
[255,255,212],$  ;butter
[255,160,122],$  ;light salmon
[205,92,92],$  ;indian red
[255,0,0],$  ;red
[139,0,0],$  ;dark red
[255,192,203],$  ;pink
[255,105,180],$  ;hot pink
[255,20,147],$  ;deep pink
[216,191,216],$  ;thistle
[153,50,204],$  ; dark orchid
[128,0,128], $  ;purple
[255,140,0],$  ;dark orange
[255,215,0],$  ;gold
[173,255,47],$  ;SpringGreen
[152,251,152],$  ;pale green
[0,80,0],$  ;green
[128,128,0],$  ;olive
[176,196,222],$  ;light steel blue
[0,139,139],$  ;dark cyan
[0,255,255],$  ;cyan
[173,216,230],$  ;powder blue
[65,105,225],$  ;royal blue
[0,0,255] $  ;blue
]

red=rgb24[0,*]
grn=rgb24[1,*]
blu=rgb24[2,*]

red = [  0, 255,   0, 255,   0, 255,   0, 255,   0, 127, 219, $
       255, 255, 112, 219, 127,   0, 255, 255,   0, 112, 219]
grn = [  0,  0, 208, 255, 255,   0,   0, 0,   0, 219,   0, $
       187, 127, 219, 112, 127, 166, 171, 171, 112, 255,   0]
blu = [  0, 191, 255,   0,   0,   0, 255, 171, 255, 219, 115, $
         0, 127, 147, 219, 127, 255, 127, 219,   0 ,  0, 255]
tvlct, red, grn, blu, 0


; ******************************************************************
; **** this logic assumes 21 stations in the array station_names ***
; ******************************************************************

i_plot = 0
i_station = 0

!P.MULTI = [0,2,nstations/2]
;!P.MULTI = [0,nstations/2,2]
;!P.MULTI = [0,2,8]
!Y.MARGIN = [2,1]
!X.MARGIN = [2,2]
!Y.OMARGIN = [1,1]
!X.OMARGIN = [1,1]

FOR i=0,nstations-1 DO BEGIN
;  index = WHERE((station_names[i] EQ site_arr[*]) AND (num_samples_arr[*] GE 50))
  index = WHERE(station_names[i] EQ site_arr[*])
; if there are less than 50 samples per event then don't worry about checking bounds
; for it ... in other words, it is ok to plot that event 
print, station_names[i], index[0]  ; beginning data record for this station
  IF (index[0] LT 0) THEN GOTO, skip_p  

 ; find the outliers with any cases of bias exceeding +/- 3 dBZ
;  check_bounds = TOTAL(y_mean_arr[index] LT -3.0)  + TOTAL(y_mean_arr[index] GT 3.0)
PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-4.5,4.5], XSTYLE=1, ystyle = 1, $
      /nodata, BACKGROUND='FFFFFF'XL, COLOR='000000'XL, ycharsize=1, xcharsize=0.1, xticks=1, xtickformat='(I1)'
OPLOT, [x_range[0],x_range[1]], [0,0], COLOR=0, linestyle=1

         IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN BEGIN
            OPLOT, x_date_arr[index], y_mean_arr[index], COLOR=0, thick=1 ;, PSYM=-2, SYMSIZE=0.5
            OPLOT, x_date_arr[index], y_mean_arr2[index], COLOR=0, thick=1, LINESTYLE=2
         ENDIF ELSE BEGIN
            OPLOT, x_date_arr[index], smooth(y_mean_arr[index],nsmooth), COLOR=0, thick=1 ;, PSYM=-2, SYMSIZE=0.5
            OPLOT, x_date_arr[index], smooth(y_mean_arr2[index],nsmooth), COLOR=0, thick=1, LINESTYLE=2
         ENDELSE
         PRINT, '***plotted ', station_names[i]
         xval = x_range[0] +  1.2*(x_range[1] - x_range[0])/(1.0 * N_ELEMENTS(station_names))  
         XYOUTS, x_range[1]-175, 2.0, station_names[i], COLOR=0, $
                 charsiz=0.6, charthick=1, /data  ; using data coordinates
         i_plot = i_plot + 1 ; counter for printing station names

x_loc = [200., 360., 510., 725., 900.]
y_loc = [-6.75, -6.75, -6.75, -6.75, -6.75]
xy_dates = ['AUG06', 'JAN07', 'JUN07', 'JAN08', 'JUN08']
;IF i GT nstations-3 THEN $
     XYOUTS, x_loc, y_loc, xy_dates, COLOR=0, charsize=0.6

GOTO, skip_over
skip_p: PRINT, '****no events for station '
skip_over:
ENDFOR


GOTO, skipto
IO_bailout: PRINT, '***** IO error encountered'
PRINT, !ERROR_STATE.MSG
PRINT, 'finished this many events: ', num_events
GOTO, skipto

skipto: 

 DEVICE, /CLOSE_FILE
 SET_PLOT, entry_device

end_it:
PRINT, 'finished'

END
