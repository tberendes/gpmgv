    pro mk_qreo_multi, siteID, srlon, srlat, alt, nominal 
;
; *** Program to create a REORDER .inp file.
;
;
; *** Set up some parameters.  Edit these as appropriate
; 
    xmin = '-148' & xmax = '148' & xspacing = '4.0'
    ymin = '-148' & ymax = '148' & yspacing = '4.0'
    zmin = '1.5' & zmax = '19.5' & zspacing = '1.5'
    
    azradius = '0.5' & elradius = '0.5' & rgradius = '1.0'
    wfunc = 'CRESSMAN'
    
    exp = siteID & instrument = siteID
;    Get the radar lat and lon
;
; *** Name the output file
;    
    out_file = 'reorder_temp.inp'
    print,out_file
;
; *** Open the file for writing
;
    openw,unit,out_file,/get_lun
;
; *** Write some standard info
;    
    printf,unit,';'
    printf,unit,'NETCDF:"./";'
    printf,unit,'INPUT: "./test.uf";'
    printf,unit,'OUTPUT: "./junk";'
    printf,unit,';'
    printf,unit,'RLONGITUDE: ' + srlon + '; RLATITUDE:' + srlat + $
                '; RALTITUDE:' + alt + ';'
    printf,unit,'GLONGITUDE: ' + srlon + '; GLATITUDE:' + srlat + $
                '; GALTITUDE:' + alt + ';'
    printf,unit,';'
    
    printf,unit,'XMIN:' + xmin + '; XMAX:' + xmax + '; XSPACING:' + $
      xspacing + ';' 

    printf,unit,'YMIN:' + ymin + '; YMAX:' + ymax + '; YSPACING:' + $
      yspacing + ';' 

    printf,unit,'ZMIN:' + zmin + '; ZMAX:' + zmax + '; ZSPACING:' + $
      zspacing + ';' 

    printf,unit,';'
    printf,unit,'AZRADIUS:' + azradius + '; ELRADIUS:' + elradius + $
      '; RGRADIUS:' + rgradius + ';'
    printf,unit,'WEIGHTING FUNCTION: ' + wfunc
    printf,unit,';'
    
    CASE siteID of
       'DARW' : begin
                   field1 = 'UZ'
                   printf,unit,'DBZFIELD:' + field1 + ';'
                end
       'RMOR' : begin
                  field1 = 'CZ' & mnem1 = 'PROPOGCOR'
                  field2 = 'DZ' & mnem2 = 'NOPROPOGCOR'
                  printf,unit,'DBZFIELD:' + field1 + ', ' + mnem1 + ';'
                  printf,unit,'DBZFIELD:' + field2 + ', ' + mnem2 + ';'
                end
        ELSE :  begin
                  field1 = 'CZ'
                  printf,unit,'DBZFIELD:' + field1 + ';'
                end
    ENDCASE

   printf,unit,'EXPERIMENT: ' + exp + '; INSTRUMENT:' + siteID + ';'
   printf,unit,';'

;    sdate = '01-' + the_month + '-' + strmid(year,2,2) + ', 00:00:00;'
    printf,unit,'START:' + nominal + ';'

 ;   sdpm = strtrim(string(dpm),2)
 ;   edate = sdpm + '-' + the_month + '-' + strmid(year,2,2) + ', 23:59:59;'
    printf,unit,';'
    printf,unit,'SPANVOLUMES;'
    printf,unit,'quit;'

    close,unit
    free_lun,unit

end


    
