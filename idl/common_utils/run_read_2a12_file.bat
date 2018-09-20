common sample, start_sample, sample_range, NLAYER_TMI, NPIXEL_TMI, NSPECIES

@tmi_params.inc
;@environs.inc

SAMPLE_RANGE=0
START_SAMPLE=0
END_SAMPLE=0
;NLAYER_TMI = 14   ; now 'included' via tmi_params.inc
;NPIXEL_TMI=208    ; now 'included' via tmi_params.inc
print, NLAYER_TMI, NPIXEL_TMI
print

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
           sst = FLTARR(sample_range>1, NPIXEL_TMI)
    chiSquared = INTARR(sample_range>1, NPIXEL_TMI)
           PoP = inTARR(sample_range>1, NPIXEL_TMI)
freezingHeight = INTARR(sample_range>1, NPIXEL_TMI)
;     scan_time = DBLARR(sample_range>1)
     st_struct = "scan_time structure"   ; just define anything
frac_orbit_num = FLTARR(sample_range>1)

;file21_2do='/tmp/2A12.100826.72798.6.sub-GPMGV1.hdf'
file21_2do='/tmp/2A12_CSI.20101230.74757.KWAJ.7.HDF.gz'
;file21_2do='/tmp/2A12_CSI.101230.74757.KWAJ.6.HDF.Z'
;file21_2do='/home/morris/tEmP_FiLe.2A12.100122.69433.6.HDF'
;file21_2do='/data/gpmgv/fullOrbit/2A12/2A12.100122.69433.6.HDF.Z'

print_attributes = 1

;status=read_2a12_file( file21_2do, $
status=read_tmi_2a12_fields( file21_2do, $
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
                       SST=sst, $
                       CHISQUARED=chiSquared, $
                       POP=PoP, $
                       FREEZINGHEIGHT=freezingHeight, $
                       GEOL=geolocation, $
                       SC_LAT_LON=sc_lat_lon, $
                       SCAN_TIME=scan_time, $
                       ST_STRUCT=st_struct, $
                       FRACTIONAL=frac_orbit_num, $
                       PRINT_ATTRIBUTES=print_attributes )
