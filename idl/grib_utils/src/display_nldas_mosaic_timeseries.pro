; docformat = 'rst'
;+
; Plots the variation of snow depth around Madison, WI over the snow events 
; at the end of January 2012.
;
; :pre:
;  The IDL SAVE file 'nldas_mosaic_msn_snowdepth.sav'
;
; :author:
;	Mark Piper, VIS, 2012
;-
pro display_nldas_mosaic_timeseries, save=save
   compile_opt idl2
   
   ; Restores the variable 'msn_snowdepth', holding the snow depth values
   ; for the four closest grid points to Madison, WI, for the 10 NLDAS-2
   ; Mosaic files in the webinar data/ directory.
   f = file_which('nldas_mosaic_msn_snowdepth.sav')
   restore, f, /verbose
   
   sd = msn_snowdepth.toarray()
   
   sd_mean = mean(sd.val, dimension=1)
   sd_stdev = stddev(sd.val, dimension=1)
   
   ; The start and end times could instead be retrieved from the files.
   time_min = julday(1,20,2012,12,0,0)
   time_max = julday(1,29,2012,12,0,0)
   time = timegen(start=time_min, final=time_max)
   
   p = errorplot(time, sd_mean, sd_stdev, $
      errorbar_color='cornflower', $
      errorbar_capsize=0.1, $
      color='burlywood', $
      symbol='square', $
      sym_color='black', $
      /sym_filled, $
      sym_size=0.75, $
      xtickunits='days', $
      xrange=[julday(1,20,2012,0,0,0), julday(1,30,2012,0,0,0)], $
      xtickformat='(C(CMoA,1x,CDI))', $
      xtitle='Time (UTC)', $
      ytitle='Snow depth (m)', $
      title='NLDAS-2 Mosaic LSM : Snow Depth : Madison, WI : 2012 Jan 20-29')
   txt = 'Mean and standard deviation!cof four neighboring grid points!cat 1200 UTC'
   t = text(0.60, 0.25, txt, font_size=10, font_color='gray')
   
   if keyword_set(save) then $
      p.save, 'nldas-mosaic-msn-snowdepth.eps'
end

; Example
display_nldas_mosaic_timeseries, save=0
end
