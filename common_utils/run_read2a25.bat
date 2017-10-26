COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN
@pr_params.inc
@environs.inc
  ; initialize PR variables/arrays and read 2A25 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_2A25
   dbz_2a25=FLTARR(sample_range>1,1,num_range)
   rain_2a25 = FLTARR(sample_range>1,1,num_range)
   surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
   geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
   rangeBinNums=INTARR(sample_range>1,RAYSPERSCAN,7)
   rainFlag=INTARR(sample_range>1,RAYSPERSCAN)
   rainType=INTARR(sample_range>1,RAYSPERSCAN)
   pia=FLTARR(3,RAYSPERSCAN,sample_range>1)
file_2a25 = '/tmp/PRv7test/2A25.20080515.59805.v7.v6.944.HDF.gz'
file_2a25 = '/data/gpmgv/prsubsets/2A25/2A25.080616.60312.6.sub-GPMGV1.hdf.gz'
   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag, PIA=pia )
help
file_2a25 = '/data/gpmgv/fullOrbit/2A25/2A25.20100131.69576.7.HDF.Z'
   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag, PIA=pia )
help
