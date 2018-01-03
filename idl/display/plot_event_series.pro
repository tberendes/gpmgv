;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_event_series.pro
;
; This procedure plots average site reflectivity for each event over time, Each 
; site had a different plot symbol
; FEB 22 this version successfully generates plots
; FEB 26 this  version plots each station with a separate symbol
; MARCH 25 this version allows you to make plot decisions based on the
;          number of samples in each event
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO plot_event_series, file, NSMOOTH=nsmooth
On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

station_names = ['KAMX','KBMX','KBRO','KBYX','KCLX','KCRP','KDGX','KEVX',$
                 'KFWS','KGRK','KHGX','KHTX','KJAX','KJGX','KLCH','KLIX',$
                 'KMLB','KMOB','KSHV','KTBW','KTLH','KWAJ','RGSN','RMOR']
;station_names = ['KHTX','RMOR']
other_station_names = STRARR(N_ELEMENTS(station_names))
; all stations in the input file that will be plotted = 24 stations
nstations = N_ELEMENTS( station_names )

; filename of the input data file -- see query in dbzdiff_stats_by_dist.sql for creation
;f_name='event_best_diffs100.txt'
plot_dir='/tmp'
;file_name = '/' + f_name
;OPENR, r_lun, plot_dir+file_name, /GET_LUN, ERROR=err
OPENR, r_lun, file, /GET_LUN, ERROR=err
PRINT, 'error code', err

PRINT, ' '
PRINT, 'reading from file:'
PRINT, '   ', file  ;plot_dir + file_name

; read header info and un-interesting rows of the 1st record
a_line = ' '
;PRINT, 'reading header info'
;FOR i=0,4 DO BEGIN
; READF, r_lun, a_line ; skip all of the header info + the 1st 2 lines of stats
; PRINT, '**header** ', a_line
;ENDFOR
;PRINT, 'header info read successfully'

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

log_name = plot_dir + '/plot_logfile/' + timedate + '.txt'
OPENW, outlun_stats, log_name, /GET_LUN, ERROR=err

; entry_device = !d.name
; SET_PLOT, 'PS'
; DEVICE, /LANDSCAPE, FILENAME=dir_name + out_file + timedate + '.ps'
; !P.COLOR=0 ; make the title and axis annotation black
; !X.THICK=4 ; make the ticks thicker
; !Y.THICK=4 ; ditto
; !P.FONT=0 ; use the device fonts supplied by postscript

event_ID   = ' '
site_name  = ' '
event_date = ' '
num_events = 0
total_stations = 0
yrstart = 3000
yrend = 0
event_data = ''
WHILE (EOF(r_lun) NE 1) DO BEGIN  ; *****loop through a all records*****
  READF, r_lun, event_data
;  total_stations = <<count total number of stations here>>
;  PRINT, event_ID, site_name, event_date, num_samples
  num_events = num_events+1
  parsed = strsplit( event_data, '|', /extract )
  event_date = parsed[1]
  i_year  = FIX(STRMID(event_date,0,4))
  yrstart = yrstart < i_year             ; earliest year in file
  yrend = yrend > i_year                 ; latest year in file
ENDWHILE
PRINT, 'total number of events = ', num_events

FREE_LUN, r_lun

;OPENR, r_lun, plot_dir+file_name, /GET_LUN, ERROR=err
OPENR, r_lun, file, /GET_LUN, ERROR=err

site_arr   = STRARR(num_events)
x_date_arr = FLTARR(num_events)
y_mean_arr = FLTARR(num_events)
;SEmean_arr = FLTARR(num_events)
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
;  SEmean_arr[i-1] = SQRT(e_var)/SQRT(num_samples)
  x_date_arr[i-1] = yr_to_date + i_day
  IF ((i_year MOD 4) EQ 0) THEN day_fact=366 ELSE day_fact=365

; ******************************************************************
; ** this logic computes days since 1 Jan of 1st year in dataset ***
; ******************************************************************
  x_date_arr[i-1] = x_date_arr[i-1] + (i_year-yrstart) * day_fact
;  print, i_year, i_month, i_day, yr_to_date + i_day, x_date_arr[i-1]

  IF (i EQ 1) THEN BEGIN ; find the bounds for the plot axes
    x_range[0] = x_date_arr[i-1]
    y_range[0] = y_mean_arr[i-1]
    x_range[1] = x_date_arr[i-1]
    y_range[1] = y_mean_arr[i-1]
  ENDIF ELSE BEGIN
    IF (x_date_arr[i-1] GT x_range[1]) THEN x_range[1] = x_date_arr[i-1]
    IF (x_date_arr[i-1] LT x_range[0]) THEN x_range[0] = x_date_arr[i-1]
    IF (y_mean_arr[i-1] GT y_range[1]) THEN y_range[1] = y_mean_arr[i-1]
    IF (y_mean_arr[i-1] LT y_range[0]) THEN y_range[0] = y_mean_arr[i-1]
  ENDELSE
ENDFOR

FREE_LUN, r_lun

; expand the plot boundaries by 2.5%
x_range[0] = FIX((x_range[0] - 0.025 * (x_range[1] - x_range[0]))*10.)/10
x_range[1] = FIX((x_range[1] + 0.025 * (x_range[1] - x_range[0]))*10.)/10
y_range[0] = y_range[0] - 0.025 * (y_range[1] - y_range[0])
y_range[1] = y_range[1] + 0.025 * (y_range[1] - y_range[0])

device, decomposed=0, RETAIN=2
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN addtext=', unsmoothed.' ELSE addtext=', smoothed.'

; generate the plot frames, in black
window, 0, xsize=700, ysize=500, TITLE='Sites with all cases within 3 dBZ bias to PR'+addtext
;PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-5.0,5.0], XSTYLE=1, ystyle = 1, $
;      /nodata, BACKGROUND='696969'XL, COLOR='000000'XL ; background=white, axis=black

;red = [  0, 255,   0, 255,   0, 255,   0, 255,   0, 127, 219, $
;       255, 255, 112, 219, 127,   0, 255, 255,   0, 112, 219]
;grn = [  0,  0, 208, 255, 255,   0,   0, 0,   0, 219,   0, $
;       187, 127, 219, 112, 127, 166, 171, 171, 112, 255,   0]
;blu = [  0, 191, 255,   0,   0,   0, 255, 171, 255, 219, 115, $
;         0, 127, 147, 219, 127, 255, 127, 219,   0 ,  0, 255]

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

tvlct, red, grn, blu, 0

PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-5.0,5.0], XSTYLE=1, ystyle = 1, $
      /nodata, BACKGROUND=1, COLOR=0 ; background=white, axis=black

; ******************************************************************
; **** this logic assumes 21 stations in the array station_names ***
; ******************************************************************

i_plot = 0
i_station = 0
FOR i=0,nstations-1 DO BEGIN
;  index = WHERE((station_names[i] EQ site_arr[*]) AND (num_samples_arr[*] GE 50))
  index = WHERE(station_names[i] EQ site_arr[*])
; if there are less than 50 samples per event then don't worry about checking bounds
; for it ... in other words, it is ok to plot that event 
print, station_names[i], index[0]  ; beginning data record for this station
  IF (index[0] LT 0) THEN GOTO, skip_p  

 ; find the outliers with any cases of bias exceeding +/- 3 dBZ
  check_bounds = TOTAL(y_mean_arr[index] LT -3.0)  + TOTAL(y_mean_arr[index] GT 3.0)

 ; plot the well-behaved sites in first plot
  IF ((N_ELEMENTS(INDEX) GT 2) AND (check_bounds EQ 0)) $ 
      THEN BEGIN
         IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN OPLOT, x_date_arr[index], $
                     y_mean_arr[index], COLOR=i+2, thick=2 $ ;, PSYM=-1 
         ELSE OPLOT, x_date_arr[index], smooth(y_mean_arr[index],nsmooth), $
                     COLOR=i+2, thick=2 ;, PSYM=-1
         PRINT, '***plotted ', station_names[i]
;         PRINT, y_mean_arr[index]
         xval = x_range[0] + i_plot * 1.2*(x_range[1] - x_range[0])/(1.0 * N_ELEMENTS(station_names))  
         XYOUTS, 50.0+xval, 4.5-((i_plot MOD 2)*0.5), station_names[i], COLOR=i+2, $
                 charsiz=2, charthick=2, /data  ; using data coordinates
         i_plot = i_plot + 1 ; counter for printing station names
      ENDIF ELSE BEGIN
         other_station_names[i_station] = station_names[i] ; that didn't get printed in Window 0
         i_station = i_station + 1
         PRINT, '***did not plot ', station_names[i]
;         PRINT, y_mean_arr[index]                          ; make an array of the stations
      ENDELSE
GOTO, skip_over
skip_p: PRINT, '****no events for station '
skip_over:
ENDFOR
; check_bounds checks to see if all events for a given station fall between +2 and -2 dB

x_loc = [200., 360., 510., 725., 900.]
y_loc = [-5.75, -5.75, -5.75, -5.75, -5.75]
xy_dates = ['AUG06', 'JAN07', 'JUN07', 'JAN08', 'JUN08']

XYOUTS, x_loc, y_loc, xy_dates, COLOR=0

window, 1, xsize=700, ysize=500, TITLE='Sites with one or more cases exceeding 3 dBZ bias'+addtext
i_plot = 0
PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-5.0,5.0], XSTYLE=1, ystyle = 1, $
      /nodata, BACKGROUND=1, COLOR=0
FOR i=0,i_station-1 DO BEGIN
  index = WHERE(other_station_names[i] EQ site_arr[*])
  stncolor = WHERE(station_names EQ other_station_names[i])
  IF (index[0] LT 0) THEN GOTO, skip_p2  

  check_bounds = TOTAL(y_mean_arr[index] LE -3.0) + TOTAL(y_mean_arr[index] GE 3.0)
  IF ((N_ELEMENTS(INDEX) GT 2) AND (check_bounds GT 0)) $ 
      THEN BEGIN
         IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN OPLOT, x_date_arr[index], $
                    y_mean_arr[index], COLOR=stncolor[0]+2, thick=2 $ ;, PSYM=-1
         ELSE OPLOT, x_date_arr[index], smooth(y_mean_arr[index],5), $
                     COLOR=stncolor[0]+2, thick=2
         PRINT, '***plotted ', other_station_names[i]
;         PRINT, y_mean_arr[index]
         i_plot = i_plot + 1 ; counter for printing station names
         xval = x_range[0] + i_plot * 1.2*(x_range[1] - x_range[0])/(1.0 * N_ELEMENTS(station_names))  
;         XYOUTS, 50.0 + xval, 5., other_station_names[i], COLOR=i, /data ; using data coordinates
         XYOUTS, 50.0+xval, 4.5-((i_plot MOD 2)*0.5), other_station_names[i], COLOR=stncolor[0]+2, $
                 charsiz=2, charthick=2, /data  ; using data coordinates
      ENDIF ELSE BEGIN
         PRINT, '***did not plot ', other_station_names[i]
         PRINT, y_mean_arr[index]
      ENDELSE
GOTO, skip_over2
skip_p2: PRINT, '****no events for station '
skip_over2:
ENDFOR
; check_bounds checks to see if all events for a given station fall between +2 and -2 dB
XYOUTS, x_loc, y_loc, xy_dates, COLOR=0

GOTO, skipto
IO_bailout: PRINT, '***** IO error encountered'
PRINT, !ERROR_STATE.MSG
PRINT, 'finished this many events: ', num_events
GOTO, skipto
skipto: 

; DEVICE, /CLOSE_FILE
; SET_PLOT, entry_device

end_it:
PRINT, 'finished'

END
