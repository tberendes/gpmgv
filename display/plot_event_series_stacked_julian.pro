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

PRO plot_event_series_stacked_julian, file, NSMOOTH=nsmooth
On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

station_names = ['KAMX','KBMX','KBRO','KBYX','KCLX','KCRP','KDGX','KEVX',$
                 'KFWS','KGRK','KHGX','KHTX','KJAX','KJGX','KLCH','KLIX',$
                 'KMLB','KMOB','KSHV','KTBW','KTLH','RMOR']
; all stations in the input file that will be plotted = 24 stations
nstations = N_ELEMENTS( station_names )

; see query in dbzdiff_stats_by_dist.sql for filename of the input data file
;f_name='event_best_diffs100.txt'
plot_dir='/tmp'
OPENR, r_lun, file, /GET_LUN, ERROR=err
PRINT, 'error code', err

PRINT, ' '
PRINT, 'reading from file: ', file

a_line = ' '
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
ENDWHILE
PRINT, 'total number of events = ', num_events

FREE_LUN, r_lun

OPENR, r_lun, file, /GET_LUN, ERROR=err

site_arr   = STRARR(num_events)
x_date_arr = FLTARR(num_events)
y_mean_arr = FLTARR(num_events)
num_samples_arr = LONARR(num_events)
x_range    = LONARR(2)  ; index 0 is min, index 1 is max
y_range    = FLTARR(2)  ; index 0 is min, index 1 is max

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

   num_samples_arr[i-1] = num_samples
   site_arr[i-1]   = site_name  
   y_mean_arr[i-1] = e_mean
   x_date_arr[i-1] = JULDAY(i_month,i_day,i_year)

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

CALDAT, x_range[0], monthstart, daystart, yrstart
CALDAT, x_range[1], monthend, dayend, yrend

; round start date of plots to beginning of quarter
CASE (monthstart-1)/3 OF
    0 : monthstart = 1
    1 : monthstart = 4
    2 : monthstart = 7
    3 : monthstart = 10
ENDCASE
x_range[0] = JULDAY(monthstart,1,yrstart)
print, monthstart,yrstart

CASE (monthend-1)/3 OF
   0 : monthend = 4
   1 : monthend = 7
   2 : monthend = 10
   3 : BEGIN
          yrend = yrend+1
          monthend = 1
       END
ENDCASE
x_range[1] = JULDAY(monthend,1,yrend)
print, monthend,yrend

device, decomposed=0, RETAIN=2
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN addtext=', unsmoothed.' ELSE addtext=', smoothed.'

; generate the plot frames, in black
window, 0, xsize=1000, ysize=850 ;, TITLE='Sites with all cases within 3 dBZ bias to PR'+addtext

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

i_plot = 0
i_station = 0

!P.MULTI = [0,2,nstations/2]
!Y.MARGIN = [4,2]
!X.MARGIN = [4,4]
!Y.OMARGIN = [4,4]
!X.OMARGIN = [4,4]

FOR i=0,nstations-1 DO BEGIN
  index = WHERE(station_names[i] EQ site_arr[*])
  print, station_names[i], index[0]  ; beginning data record for this station
  IF (index[0] LT 0) THEN GOTO, skip_p  

  PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-4.5,4.5], $
        XSTYLE=1, ystyle = 1, /nodata, BACKGROUND=1, COLOR=0, $
        ycharsize=1.5, xcharsize=0.1, xticks=1, xtickformat='(I1)'
  ; plot the zero-bias line
  OPLOT, [x_range[0],x_range[1]], [0,0], COLOR=0, linestyle=1
  ; plot either smoothed or raw biases
  IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN $
    OPLOT, x_date_arr[index], y_mean_arr[index], COLOR=0, thick=1 , PSYM=-2 $
  ELSE $
    OPLOT, x_date_arr[index], smooth(y_mean_arr[index],nsmooth), COLOR=0, thick=1, PSYM=-2
  PRINT, '***plotted ', station_names[i]
  ; plot the station ID inside the plot box
  xval = x_range[0] +  (x_range[1] - x_range[0])*7/8  
  XYOUTS, xval, 2.0, station_names[i], COLOR=0, $
          charsiz=1, charthick=1, /data  ; using data coordinates
  i_plot = i_plot + 1 ; counter for printing station names

  ; how many months are in plot x-range?
  monthrange = (1 + 12 - monthstart) + (yrend-yrstart-1 > 0)*12 + monthend
  ;print, monthrange
  ; we have room for about 10 labels for month of year, what is the step?
  step = (((monthrange-1)/5)/3)*3
  ;print, step
  months=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
  months1=['J','F','M','A','M','J','J','A','S','O','N','D']
  yrlast = yrstart
;  FOR mm = 0, monthrange, step DO BEGIN
  FOR mm = 0, monthrange-1 DO BEGIN
    plotmonth = ((monthstart+mm-1) MOD 12) + 1
    plotyr = yrstart + (monthstart+mm-1)/12
;    print, mm, ' plotmonth: ', plotmonth, ' plotyr: ', plotyr
;    print, 'step: ', step, ' plotmonth: ', plotmonth, ' plotyr: ', plotyr
;    print, months[plotmonth-1], plotyr
    x_loc_mm = JULDAY(plotmonth,1,plotyr)
    quote = "'"
;    XYOUTS, x_loc_mm, -6.75, months[plotmonth-1] + quote + $
;            string(plotyr-(plotyr/100)*100,FORMAT='(i2.2)'), COLOR=0
    XYOUTS, x_loc_mm, -6.75, months1[plotmonth-1], COLOR=0
   ; mark the year boundaries with a vertical line
    IF ( plotyr NE yrlast ) THEN BEGIN
       x_loc_yy = JULDAY(1,1,plotyr)
       OPLOT, [x_loc_yy,x_loc_yy], [-4.5,4.5], COLOR=0, linestyle=1
       XYOUTS, x_loc_yy, -9.0, STRING(plotyr,FORMAT='(i4)'), COLOR=0
       yrlast = plotyr
    ENDIF
  ENDFOR

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

end_it:
PRINT, 'finished'

END
