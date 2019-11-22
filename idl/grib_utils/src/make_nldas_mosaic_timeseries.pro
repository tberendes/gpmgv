; docformat = 'rst'
;+
; Makes an IDL 8.1 SAVE file containing the snowdepth data near Madison, WI
; from all 10 of the NLDAS-2 Mosaic GRIB 1 files in the webinar data/ directory. 
;
; :uses:
;  NLDAS_FIND_NEAREST
;
; :author:
;	Mark Piper, VIS, 2012
;-
pro make_nldas_mosaic_timeseries
   compile_opt idl2
   
   ; XXX: Replace with GET_PROJECT_DIR.
   root_dir = '/home/mpiper/projects/GRIB-webinar/data'
   files = file_search(root_dir, '*.grb', count=nfiles)
   if nfiles eq 0 then return

   snowdepth_id = 66 ; from NLDAS README
   msn = [43.1, -89.4]
   msn_snowdepth = list()
   foreach f, files do $
      msn_snowdepth.add, nldas_find_nearest(f, snowdepth_id, msn[1], msn[0])

   save, msn_snowdepth, /compress, filename='nldas_mosaic_msn_snowdepth.sav'
end
