;+
; Copyright ¬© 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; plot_event_series_stacked_julian_ps2.pro
;
; This procedure plots time series of average PR-GV site reflectivity difference
; for each configured GV site in a separate panel.  The time series data are in
; the files specified as the mandatory input parameter, and are precomputed and
; resident in the gpmgv database in the dbzdiff_stats_by_dist_geo table.  SQL in
; file "dbzdiff_stats_by_dist.sql" has the SQL command needed to generate the
; input file in the necessary format. This version generates two plots
; for each station, with a separate line style. The plot with unadjusted GV Z is
; solid, and the plot with S-band adjusted to KU-band is plotted in dashed.
; The input parameter 'file' must be a two-element array of strings, with the
; file with the unadjusted GV biases in the first string, and the file with the
; GV bias computed with adjusted GV Z in the second file.
;
; Output is to a Postscript file whose name is derived from the name of the
; first input data file.
; 
; The optional parameter 'nsmooth' is an integer which specifies the number of
; points over which the time series plots are smoothed by the IDL smooth()
; function.  Default is to not smooth the plots.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

PRO plot_event_series_stacked_julian_ps2, file, NSMOOTH=nsmooth
On_IOError, IO_bailout ;  bailout if there is an error reading or writing a file

IF N_ELEMENTS( file ) NE 2 THEN BEGIN
   print, 'Formal file parameter must be an array of size 2.'
   print, 'Must contain 2 strings specifying input file pathnames.'
   help, file
   goto, end_it
ENDIF

station_names = ['KAMX','KBMX','KBRO','KBYX','KCLX','KCRP','KDGX','KEVX',$
                 'KFWS','KGRK','KHGX','KHTX','KJAX','KJGX','KLCH','KLIX',$
                 'KMLB','KMOB','KSHV','KTBW','KTLH','RMOR']
;station_names = ['KHTX','RMOR']
other_station_names = STRARR(N_ELEMENTS(station_names))
; all stations in the input file that will be plotted = 24 stations
nstations = N_ELEMENTS( station_names )

; generate the filename for postscript output
plot_dir='/tmp'
outfile_name = FILE_BASENAME(file[0], '.txt')
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN addtext='_unsmoothed' $
ELSE addtext='_smoothed_by_' + STRING(nsmooth, FORMAT='(I0)')
psoutname = plot_dir+'/'+outfile_name+addtext+'.ps'
print, psoutname

OPENR, r_lun, file[0], /GET_LUN, ERROR=err
PRINT, 'error code', err
PRINT, ' '
PRINT, 'reading from file:'
PRINT, '   ', file[0]

 entry_device = !d.name
 SET_PLOT, 'PS'
 DEVICE, /portrait, FILENAME=psoutname, COLOR=1, BITS_PER_PIXEL=8, $
         xsize=7, ysize=9.5, xoffset=0.75, yoffset=0.75, /inches
; !P.COLOR=0 ; make the title and axis annotation black
; !X.THICK=4 ; make the ticks thicker
; !Y.THICK=4 ; ditto
 !P.FONT=0 ; use the device fonts supplied by postscript

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
  num_events = num_events+1
;  parsed = strsplit( event_data, '|', /extract )
;  event_date = parsed[1]
;  i_year  = FIX(STRMID(event_date,0,4))
;  yrstart = yrstart < i_year             ; earliest year in file
;  yrend = yrend > i_year                 ; latest year in file
ENDWHILE
PRINT, 'total number of events = ', num_events

FREE_LUN, r_lun

PRINT, ' '
PRINT, 'reading from files:'
PRINT, '   ', file[0], "  :  ",file[1]
OPENR, r_lun, file[0], /GET_LUN, ERROR=err
PRINT, 'error code', err
OPENR, r_lun2, file[1], /GET_LUN, ERROR=err
PRINT, 'error code', err

site_arr   = STRARR(num_events)
x_date_arr = FLTARR(num_events)
y_mean_arr = FLTARR(num_events)
y_mean_arr2 = FLTARR(num_events)
num_samples_arr = LONARR(num_events)
x_range    = LONARR(2) ; index0 is min index1 is max
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

  num_samples_arr[i-1] = num_samples
  site_arr[i-1]   = site_name  
  y_mean_arr[i-1] = e_mean
  y_mean_arr2[i-1] = e_mean2
  x_date_arr[i-1] = JULDAY(i_month,i_day,i_year)

; ******************************************************************
; ** this logic computes days since 1 Jan of 1st year in dataset ***
; ******************************************************************
;  x_date_arr[i-1] = x_date_arr[i-1] + (i_year-yrstart) * day_fact
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

CALDAT, x_range[0], monthstart, daystart, yrstart
CALDAT, x_range[1], monthend, dayend, yrend

; round start date of plots to beginning of quarter
CASE (monthstart-1)/3 OF
;   0 : BEGIN
;          yrstart = yrstart-1
;          monthstart = 10
;       END
;   1 : monthstart = 1
;   2 : monthstart = 4
;   3 : monthstart = 7
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

; expand the plot boundaries by 2.5%
;x_range[0] = LONG((x_range[0] - 0.025 * (x_range[1] - x_range[0]))*10.)/10
;x_range[1] = LONG((x_range[1] + 0.025 * (x_range[1] - x_range[0]))*10.)/10
;y_range[0] = y_range[0] - 0.025 * (y_range[1] - y_range[0])
;y_range[1] = y_range[1] + 0.025 * (y_range[1] - y_range[0])

;device, decomposed=0, RETAIN=2

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
; set the margins, in characters, around each individual plot
!Y.MARGIN = [2,1]
!X.MARGIN = [3,2]
; set the margins for the outside borders of the multiplot area
!Y.OMARGIN = [1,0]
!X.OMARGIN = [2,0]

; --- Define symbol as filled circle
   A = FINDGEN(17) * (!PI*2/16.)
   symx = COS(A)
   symy = SIN(A)
   USERSYM, symx, symy ;, /FILL
   

FOR i=0,nstations-1 DO BEGIN
;  index = WHERE((station_names[i] EQ site_arr[*]) AND (num_samples_arr[*] GE 50))
  index = WHERE(station_names[i] EQ site_arr[*], n_sta_events)
; if there are less than 50 samples per event then don't worry about checking bounds
; for it ... in other words, it is ok to plot that event 
print, station_names[i], index[0]  ; beginning data record for this station
  IF (index[0] LT 0) THEN GOTO, skip_p  

PLOT, x_date_arr, y_mean_arr, XRANGE=x_range, YRANGE=[-4.5,4.5], XSTYLE=1, ystyle = 1, $
      /nodata, BACKGROUND='FFFFFF'XL, COLOR='000000'XL, $
      ycharsize=1.25, xcharsize=0.1, xticks=1, xtickformat='(I1)'
; plot the zero-bias line
OPLOT, [x_range[0],x_range[1]], [0,0], COLOR=0, linestyle=1

; plot either smoothed or raw biases.  Skip S-to-Ku-adjusted plot for RMOR C-band.
IF ( N_ELEMENTS(nsmooth) NE 1 ) THEN BEGIN
    OPLOT, x_date_arr[index], y_mean_arr[index], COLOR=0, $
           thick=1 , PSYM=-2, SYMSIZE=0.5
    IF station_names[i] NE 'RMOR' then OPLOT, x_date_arr[index], y_mean_arr2[index], $
           COLOR=0, thick=1, LINESTYLE=2 ;, PSYM=-5, SYMSIZE=0.5
ENDIF ELSE BEGIN
    OPLOT, x_date_arr[index], smooth(y_mean_arr[index],nsmooth), COLOR=0, $
           thick=1 , PSYM=-2, SYMSIZE=0.5
    IF station_names[i] NE 'RMOR' then OPLOT, x_date_arr[index], $
           smooth(y_mean_arr2[index],nsmooth), COLOR=0, thick=1, LINESTYLE=2
ENDELSE

; plot circles at the datapoints, sized according to cube root of the
; number of samples in the case
;xsta = x_date_arr[index] & ysta = y_mean_arr[index] & ncases = num_samples_arr[index]
;for isamp = 0, n_sta_events-1 do begin
;    OPLOT, [xsta[isamp],xsta[isamp]], [ysta[isamp],ysta[isamp]], COLOR=0, $
;           thick=1, PSYM=8, SYMSIZE=(ncases[isamp])^(1./3.)/5. ;ALOG10(ncases[isamp])/5. ;sqrt(ncases[isamp])/25.0
;print, 'SIZE = ', SQRT(ncases[isamp])
;endfor

PRINT, '***plotted ', station_names[i]
; plot the station ID inside the plot box
xval = x_range[0] +  (x_range[1] - x_range[0])*7/8  
XYOUTS, xval, 2.0, station_names[i], COLOR=0, $
        charsiz=0.6, charthick=1, /data  ; using data coordinates
i_plot = i_plot + 1 ; counter for printing station names

; how many months are in plot x-range?
monthrange = (1 + 12 - monthstart) + (yrend-yrstart-1 > 0)*12 + monthend
;print, monthrange
; we have room for about 10 labels for month of year, what is the step?
step = (((monthrange-1)/5)/3)*3
;print, step
months=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
yrlast = yrstart
quote = "'"
FOR mm = 0, monthrange, step DO BEGIN
    plotmonth = (monthstart+mm) MOD 12
    plotyr = yrstart + (monthstart+mm)/12
;    print, 'step: ', step, ' plotmonth: ', plotmonth, ' plotyr: ', plotyr
;    print, months[plotmonth-1], plotyr
    x_loc_mm = JULDAY(plotmonth,1,plotyr)
    XYOUTS, x_loc_mm, -6.25, months[plotmonth-1] + quote +   $
            string(plotyr-(plotyr/100)*100,FORMAT='(i2.2)'), $
            COLOR=0, charsiz=0.6, charthick=1
    IF ( plotyr NE yrlast ) THEN BEGIN
      ; plot a vertical dotted line at the year break
       x_loc_yy = JULDAY(1,1,plotyr)
       OPLOT, [x_loc_yy,x_loc_yy], [-4.5,4.5], COLOR=0, linestyle=1
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

 DEVICE, /CLOSE_FILE
 SET_PLOT, entry_device

end_it:
PRINT, 'finished'

END
