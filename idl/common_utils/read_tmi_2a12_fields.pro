;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; read_tmi_2a12_fields.pro -- Wrapper function to read data fields of interest
;   from TMI 2a12 products.  Handles finding, safe copy, and decompression of
;   the 2a12 file.
;
; AUTHOR:
;       Bob Morris, SAIC
;
; MODIFIED:
;       May 2011 - Bob Morris, GPM GV (SAIC)
;       - Created.
;       July 13, 2011 - Bob Morris, GPM GV (SAIC)
;       - Added freezingHeight to the variables able to be read from the 2A-12.
;       Feb. 06, 2013 - Bob Morris, GPM GV (SAIC)
;       - Added V7 fields: windSpeed, dataQuality, qualityFlag,
;       landAmbiguousFlag, landScreenFlag, oceanExtendedDbase,
;       oceanSearchRadius, sunGlintAngle,  freezingHeightIndex,
;       clusterNumber, clusterScale
;       Oct. 7, 2014 - Bob Morris, GPM GV (SAIC)
;       - Renamed NSPECIES constant to NSPECIES_TMI
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION read_tmi_2a12_fields, file_2a12, $
                         DATAFLAG=dataFlag, $
                         RAINFLAG=rainFlag, $
                         SURFACETYPE=surfaceType, $
                         SURFACERAIN=surfaceRain, $
                         SURFRAINLIQUID=surfRainLiquid, $
                         CONVECTRAIN=convectRain, $
                         CONFIDENCE=confidence, $
                         CLDWATER=cldWater, $
                         PRECIPWATER=precipWater, $
                         CLDICE=cldIce, $
                         PRECIPICE=precipIce, $
                         LATENTHEAT=latentHeat, $
                         PIXELSTATUS=pixelStatus, $
                         TOTPRECIPWATER=totPrecipWater, $
                         CLOUDWATERPATH=cloudWaterPath, $
                         RAINWATERPATH=rainWaterPath, $
                         ICEWATERPATH=iceWaterPath, $
                         WINDSPEED=windSpeed, $
                         SST=sst, $
                         CHISQUARED=chiSquared, $
                         POP=PoP, $
                         FREEZINGHEIGHT=freezingHeight, $
                         DATAQUALITY=dataQuality, $
                         QUALITYFLAG=qualityFlag, $
                         LANDAMBIGUOUSFLAG=landAmbiguousFlag, $
                         LANDSCREENFLAG=landScreenFlag, $
                         OCEANEXTENDEDDBASE=oceanExtendedDbase, $
                         OCEANSEARCHRADIUS=oceanSearchRadius, $
                         SUNGLINTANGLE=sunGlintAngle, $
                         FRZGHEIGHTINDEX=freezingHeightIndex, $
                         CLUSTERNUMBER=clusterNumber, $
                         CLUSTERSCALE=clusterScale, $
                         GEOL=geolocation, $
                         SC_LAT_LON=sc_lat_lon, $
                         SCAN_TIME=scan_time, $
                         FRACTIONAL=frac_orbit_num, $
                         PRINT_ATTRIBUTES=print_attributes

  common sample, start_sample, sample_range, NLAYER_TMI, NPIXEL_TMI, NSPECIES_TMI

  @tmi_params.inc  ; 'include' file for NLAYER_TMI, NPIXEL_TMI, NSPECIES_TMI

;
; Check status of file_2a12 before proceeding -  actual file
; name on disk may differ if file has been uncompressed already.
;
   readstatus = 0

   havefile = find_alt_filename( file_2a12, found2a12 )
   if ( havefile ) then begin
;     Get an uncompressed copy of the found file
      cpstatus = uncomp_file( found2a12, file12_2do )
      if(cpstatus eq 'OK') then begin
;        Initialize variables for 2a12 use
         SAMPLE_RANGE=0
         START_SAMPLE=0
         END_SAMPLE=0
            geolocation = FLTARR(2, NPIXEL_TMI, sample_range>1)
             sc_lat_lon = FLTARR(2, sample_range>1)
               dataFlag = BYTARR(sample_range>1, NPIXEL_TMI)
               rainFlag = BYTARR(sample_range>1, NPIXEL_TMI)
            surfaceType = BYTARR(sample_range>1, NPIXEL_TMI)
            surfaceRain = FLTARR(sample_range>1, NPIXEL_TMI)
         surfRainLiquid = FLTARR(sample_range>1, NPIXEL_TMI)
            convectRain = FLTARR(sample_range>1, NPIXEL_TMI)
             confidence = FLTARR(sample_range>1, NPIXEL_TMI)
               cldWater = INTARR(sample_range>1, NPIXEL_TMI, NLAYER_TMI)
            precipWater = INTARR(sample_range>1, NPIXEL_TMI, NLAYER_TMI)
                 cldIce = INTARR(sample_range>1, NPIXEL_TMI, NLAYER_TMI)
              precipIce = INTARR(sample_range>1, NPIXEL_TMI, NLAYER_TMI)
             latentHeat = INTARR(sample_range>1, NPIXEL_TMI, NLAYER_TMI)
            pixelStatus = BYTARR(sample_range>1, NPIXEL_TMI)
         totPrecipWater = FLTARR(sample_range>1, NPIXEL_TMI)
         cloudWaterPath = FLTARR(sample_range>1, NPIXEL_TMI)
          rainWaterPath = FLTARR(sample_range>1, NPIXEL_TMI)
           iceWaterPath = FLTARR(sample_range>1, NPIXEL_TMI)
              windSpeed = FLTARR(sample_range>1, NPIXEL_TMI)
                    sst = FLTARR(sample_range>1, NPIXEL_TMI)
             chiSquared = INTARR(sample_range>1, NPIXEL_TMI)
                    PoP = BYTARR(sample_range>1, NPIXEL_TMI)
         freezingHeight = INTARR(sample_range>1, NPIXEL_TMI)
            dataQuality = BYTARR(sample_range>1)
            qualityFlag = BYTARR(sample_range>1, NPIXEL_TMI)
      landAmbiguousFlag = BYTARR(sample_range>1, NPIXEL_TMI)
         landScreenFlag = BYTARR(sample_range>1, NPIXEL_TMI)
     oceanExtendedDbase = BYTARR(sample_range>1, NPIXEL_TMI)
      oceanSearchRadius = BYTARR(sample_range>1, NPIXEL_TMI)
          sunGlintAngle = BYTARR(sample_range>1, NPIXEL_TMI)
    freezingHeightIndex = BYTARR(sample_range>1, NPIXEL_TMI)
          clusterNumber = BYTARR(sample_range>1, NPIXEL_TMI, NSPECIES_TMI)
           clusterScale = FLTARR(sample_range>1, NPIXEL_TMI, NSPECIES_TMI)
              scan_time = DBLARR(sample_range>1)
         frac_orbit_num = FLTARR(sample_range>1)

;        Read all fields from the uncompressed 2a12 file copy
;        Some fields only available in V6 or V7

         status=read_2a12_file( file12_2do, $
                                DATAFLAG=dataFlag, $
                                RAINFLAG=rainFlag, $
                                SURFACETYPE=surfaceType, $
                                SURFACERAIN=surfaceRain, $
                                SURFRAINLIQUID=surfRainLiquid, $
                                CONVECTRAIN=convectRain, $
                                CONFIDENCE=confidence, $
                                CLDWATER=cldWater, $
                                PRECIPWATER=precipWater, $
                                CLDICE=cldIce, $
                                PRECIPICE=precipIce, $
                                LATENTHEAT=latentHeat, $
                                PIXELSTATUS=pixelStatus, $
                                TOTPRECIPWATER=totPrecipWater, $
                                CLOUDWATERPATH=cloudWaterPath, $
                                RAINWATERPATH=rainWaterPath, $
                                ICEWATERPATH=iceWaterPath, $
                                WINDSPEED=windSpeed, $
                                SST=sst, $
                                CHISQUARED=chiSquared, $
                                POP=PoP, $
                                FREEZINGHEIGHT=freezingHeight, $
                                DATAQUALITY=dataQuality, $
                                QUALITYFLAG=qualityFlag, $
                                LANDAMBIGUOUSFLAG=landAmbiguousFlag, $
                                LANDSCREENFLAG=landScreenFlag, $
                                OCEANEXTENDEDDBASE=oceanExtendedDbase, $
                                OCEANSEARCHRADIUS=oceanSearchRadius, $
                                SUNGLINTANGLE=sunGlintAngle, $
                                FRZGHEIGHTINDEX=freezingHeightIndex, $
                                CLUSTERNUMBER=clusterNumber, $
                                CLUSTERSCALE=clusterScale, $
                                GEOL=geolocation, $
                                SC_LAT_LON=sc_lat_lon, $
                                SCAN_TIME=scan_time, $
                                FRACTIONAL=frac_orbit_num, $
                                PRINT_ATTRIBUTES=print_attributes )

         IF status NE 'OK' THEN BEGIN
            print, "read_2a12_file() returned status: '"+status+"'"
            readstatus = 1
         ENDIF
;        Delete the temporary file copy
         print, "Remove 2a12 file copy:"
         command = 'rm -fv ' + file12_2do
         spawn, command, result
         print, result
      endif else begin
         print, cpstatus
         readstatus = 1
      endelse
   endif else begin
      print, "Cannot find regular/compressed file " + file_2a12
      readstatus = 1
   endelse
   RETURN, readstatus
END
