;===============================================================================
;+
; Copyright © 2012, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; write_site_sounding_netcdf.pro -- Morris/SAIC/GPM_GV  May 2012
;
; DESCRIPTION
; -----------
; Given a structure containing model-grids-derived soundings and ancillary
; metadata and non-sounding meteorological variables, defines netCDF files
; to which the soundings and data will be written, one site sounding per file.
; Isobaric level fields in the structure will be trimmed to the number of
; levels defined by the value of the n_levels structure variable for purposes
; of defining netCDF field dimensions and writing the isobaric field variables.
;
; Returns a list of netCDF file pathnames created and written to by the function.
;
; Requires IDL Version 8 or greater, with list() object type.
;
; PARAMETERS
; ----------
; soundings - array of strutures containing the computed soundings and
;             ancillary data
; datestamp - date of the NAM analysis, in YYYYMMDD format
; cycle     - initial hour of the NAM analysis, in HHMM format
; gribfile  - array of strings defining the fully qualified path/names
;             of the NAMANL GRIB files processed
; outpath   - directory path to which the netCDF files will be written
;
; NON-SYSTEM ROUTINES CALLED
; --------------------------
; none.
;
; HISTORY
; -------
; 05/04/12 - Morris, GPM GV, SAIC
; - Created.
; 05/07/12- Morris, GPM GV, SAIC
; - Added surface soil temperature and moisture scalar variables to the file,
;   as they are now included in the sounding structures.
; 05/15/12 - Morris, GPM GV, SAIC
; - Reading grid-/earth-relative flag and 6h accumulated precipitation from site
;   sounding structure, and writing new variables 'u_v_earth_relative' and
;   'precip_6_hour' based on their values.
; - Adding two more global variables for names of source GRIB files used for
;   precip accumulation.
; 05/24/12 - Morris, GPM GV, SAIC
; - Changed gribfile parameter to an array of strings with multiple, fully-
;   qualified filenames so that the file(s) used to get precipitation grids
;   can be written to netCDF global variables.
; 05/31/12 - Morris, GPM GV, SAIC
; - Added writing of sounding file metadata to 'gpmgv' database to allow
;   tracking of complete vs. incomplete sounding extractions.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION write_site_sounding_netcdf, soundings, datestamp, cycle, gribfile, outpath

   IF N_PARAMS() LT 5 THEN $
       message, "Too few parameters, need sounding (struct), DATESTAMP, CYCLE, " $
                +"gribfile (string array[3]), and outpath."
;   IF N_PARAMS() LT 4 THEN gribfile = 'Unknown'
;   IF N_PARAMS() LT 5 THEN BEGIN
;      outpath = '/data/netcdf/soundings/NAMANL'
;      print, "In write_site_sounding_netcdf, setting output directory to ", outpath
;   ENDIF

   timestamp=STRMID(datestamp,0,4)+'-'+STRMID(datestamp,4,2)+'-'+STRMID(datestamp,6,2) $
             +' '+STRMID(cycle,0,2)+'Z'
   dbtimestamp=STRMID(datestamp,0,4)+'-'+STRMID(datestamp,4,2)+'-'+STRMID(datestamp,6,2) $
               +' '+STRMID(cycle,0,2)+':00:00+00'

   ncfiles = list()

   for siteidx=0, n_elements(soundings)-1 do begin
;      print, ''
      outfile = outpath+'/'+'Sounding.NAMANL.'+datestamp+'.'+cycle+'.'+(soundings)[siteidx].site+'.nc'

     ; Create the output dir for the netCDF file, if needed:
;      OUTDIR = FILE_DIRNAME(outfile)
;      spawn, 'mkdir -p ' + OUTDIR

      cdfid = ncdf_create(outfile, /CLOBBER)

      ; global variables
      ncdf_attput, cdfid, 'Sounding File Version', 1, /short, /global
      ncdf_attput, cdfid, 'Model Analysis Cycle', timestamp, /global
      ncdf_attput, cdfid, 'Source GRIB file', FILE_BASENAME(gribfile[0]), /global

      if n_elements(gribfile) gt 1 then $
         ncdf_attput, cdfid, 'Source GRIB file precip1', FILE_BASENAME(gribfile[1]), /global $
      else ncdf_attput, cdfid, 'Source GRIB file precip1', 'Undefined', /global

      if n_elements(gribfile) gt 2 then $
         ncdf_attput, cdfid, 'Source GRIB file precip2', FILE_BASENAME(gribfile[2]), /global $
      else ncdf_attput, cdfid, 'Source GRIB file precip2', 'Undefined', /global

      ; define scalar fields

      Site = (soundings)[siteidx].site
      sitedimid = ncdf_dimdef(cdfid, 'len_site_ID', STRLEN(Site))
      sitevarid = ncdf_vardef(cdfid, 'site_ID', [sitedimid], /char)
      ncdf_attput, cdfid, sitevarid, 'long_name', 'ID of Ground Radar Site'

      sitelatvarid = ncdf_vardef(cdfid, 'site_lat')
      ncdf_attput, cdfid, sitelatvarid, 'long_name', 'Latitude of Ground Radar Site'
      ncdf_attput, cdfid, sitelatvarid, 'units', 'degrees North'

      sitelonvarid = ncdf_vardef(cdfid, 'site_lon')
      ncdf_attput, cdfid, sitelonvarid, 'long_name', 'Longitude of Ground Radar Site'
      ncdf_attput, cdfid, sitelonvarid, 'units', 'degrees East'

      windflagvarid = ncdf_vardef(cdfid, 'u_v_earth_relative', /short)
      ncdf_attput, cdfid, windflagvarid, 'long_name', 'Flag for earth vs. grid relative winds'
      ncdf_attput, cdfid, windflagvarid, 'flag values', 'earth-relative=1, grid-relative=0, unknown=-1'
      ncdf_attput, cdfid, windflagvarid, '_FillValue', -1

      soiltempvarid = ncdf_vardef(cdfid, 'sfc_soil_t')
      ncdf_attput, cdfid, soiltempvarid, 'long_name', 'Surface Soil Temperature'
      ncdf_attput, cdfid, soiltempvarid, 'units', 'Kelvins'
      ncdf_attput, cdfid, soiltempvarid, '_FillValue', 9999.0

      soilmoistvarid = ncdf_vardef(cdfid, 'sfc_soil_moist')
      ncdf_attput, cdfid, soilmoistvarid, 'long_name', 'Volumetric Soil Moisture Content'
      ncdf_attput, cdfid, soilmoistvarid, 'units', 'fraction'
      ncdf_attput, cdfid, soilmoistvarid, '_FillValue', 9999.0

      precip6hvarid = ncdf_vardef(cdfid, 'precip_6_hour')
      ncdf_attput, cdfid, precip6hvarid, 'long_name', 'accumulated precipitation, prior 6 h'
      ncdf_attput, cdfid, precip6hvarid, 'units', 'kg/m^2'
      ncdf_attput, cdfid, precip6hvarid, '_FillValue', 9999.0

      ; define field dimensions
      pdimid = ncdf_dimdef(cdfid, 'pressureLevels', (soundings)[siteidx].n_levels)

      ; there may be fewer valid levels in the structure than there are elements
      ; in the data arrays, so define the cutoff index for the netcdf writes
      lastlevelidx = (soundings)[siteidx].n_levels-1

      ; Isobaric Levels coordinate variable
      pvarid = ncdf_vardef(cdfid, 'pressureLevels', [pdimid])
      ncdf_attput, cdfid, pvarid, 'long_name', $
                  'Pressure Level'
      ncdf_attput, cdfid, pvarid, 'units', 'mb'

      ; define sounding data fields

      tvarid = ncdf_vardef(cdfid, 'Temperature', [pdimid])
      ncdf_attput, cdfid, tvarid, 'long_name', 'Temperature analysis'
      ncdf_attput, cdfid, tvarid, 'units', 'Kelvins'
      ncdf_attput, cdfid, tvarid, '_FillValue', -9999.0

      rhvarid = ncdf_vardef(cdfid, 'RH', [pdimid])
      ncdf_attput, cdfid, rhvarid, 'long_name', 'Relative Humidity analysis'
      ncdf_attput, cdfid, rhvarid, 'units', 'percent'
      ncdf_attput, cdfid, rhvarid, '_FillValue', -9999.0

      uwindvarid = ncdf_vardef(cdfid, 'U-wind', [pdimid])
      ncdf_attput, cdfid, uwindvarid, 'long_name', 'u-wind component analysis'
      ncdf_attput, cdfid, uwindvarid, 'units', 'm/s'
      ncdf_attput, cdfid, uwindvarid, '_FillValue', -9999.0

      vwindvarid = ncdf_vardef(cdfid, 'V-wind', [pdimid])
      ncdf_attput, cdfid, vwindvarid, 'long_name', 'v-wind component analysis'
      ncdf_attput, cdfid, vwindvarid, 'units', 'm/s'
      ncdf_attput, cdfid, vwindvarid, '_FillValue', -9999.0

      ncdf_control, cdfid, /endef

      ; write the data fields to netCDF file
      ncdf_varput, cdfid, pvarid, (soundings)[siteidx].levels[0:lastlevelidx]
      ncdf_varput, cdfid, sitevarid, (soundings)[siteidx].Site
      ncdf_varput, cdfid, sitelatvarid, (soundings)[siteidx].Latitude
      ncdf_varput, cdfid, sitelonvarid, (soundings)[siteidx].Longitude
      ncdf_varput, cdfid, windflagvarid, (soundings)[siteidx].earth_relative_winds
      ncdf_varput, cdfid, soiltempvarid, (soundings)[siteidx].soiltemp
      ncdf_varput, cdfid, soilmoistvarid, (soundings)[siteidx].soilmoist
      ncdf_varput, cdfid, precip6hvarid, (soundings)[siteidx].precip6h
      ncdf_varput, cdfid, tvarid, (soundings)[siteidx].temperatures[0:lastlevelidx]
      ncdf_varput, cdfid, rhvarid, (soundings)[siteidx].RH[0:lastlevelidx]
      ncdf_varput, cdfid, uwindvarid, (soundings)[siteidx].uwind[0:lastlevelidx]
      ncdf_varput, cdfid, vwindvarid, (soundings)[siteidx].vwind[0:lastlevelidx]

      ncdf_close, cdfid

      ncfiles.add, outfile

     ; make an entry for the sounding file in the modelsoundings table in the gpmgv database
      sqlcmd = "INSERT INTO modelsoundings(cycle, radar_id, filename) VALUES('" + dbtimestamp + $
               "', '" + (soundings)[siteidx].site+ "', '" + FILE_BASENAME(outfile) + "');"
;      print, sqlcmd
      command = 'echo "' + sqlcmd + '" | psql gpmgv 2>&1'
      spawn, command, result
      IF result NE 'INSERT 0 1' THEN BEGIN
         print, ''
         print, "In write_site_sounding_netcdf.pro, database write error: "
         print, result
         print, "SQL command: "
         print, sqlcmd
         print, ''
         return, 'dbError'
      ENDIF
   endfor

return, ncfiles

end
