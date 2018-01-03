.reset_session
  common sample, start_sample, sample_range, num_range, RAYSPERSCAN
  @pr_params.inc
        SAMPLE_RANGE=0
         START_SAMPLE=0
        ; END_SAMPLE=0
         num_range = NUM_RANGE_1C21
         dbz_1c21=fltarr(sample_range>1,1,num_range)
         landOceanFlag=intarr(sample_range>1,RAYSPERSCAN)
         binS=intarr(sample_range>1,RAYSPERSCAN)
         rayStart=intarr(RAYSPERSCAN)
         scan_time_1c21=DBLARR(sample_range>1)
	 frac_orbit_1c21=FLTARR(sample_range>1)
file_1c21 = '/data/prsubsets/1C21/1C21_CSI.080112.57878.DARW.6.HDF.Z

status = read_pr_1c21_fields( file_1c21, DBZ=dbz_1c21, OCEANFLAG=landOceanFlag, BinS=binS, RAY_START=rayStart, SCAN_TIME=scan_time_1c21, FRACTIONAL=frac_orbit_1c21)


.reset_session
  common sample, start_sample, sample_range, num_range, RAYSPERSCAN
  @pr_params.inc
        SAMPLE_RANGE=0
         START_SAMPLE=0
        ; END_SAMPLE=0
         num_range = NUM_RANGE_2A25
         dbz_2a25=fltarr(sample_range>1,1,num_range)
         rain_2a25 = fltarr(sample_range>1,1,num_range)
         surfRain_2a25=fltarr(sample_range>1,RAYSPERSCAN)
         geolocation=fltarr(2,RAYSPERSCAN,sample_range>1)
         rangeBinNums=intarr(sample_range>1,RAYSPERSCAN,7)
         rainFlag=intarr(sample_range>1,RAYSPERSCAN)
         rainType=intarr(sample_range>1,RAYSPERSCAN)
         scan_time_2a25=DBLARR(sample_range>1)
	 frac_orbit_2a25=FLTARR(sample_range>1)
file_2a25 = '/data/prsubsets/2A25/2A25.060721.49456.6.sub-GPMGV1.hdf.gz'

status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25, $
                              TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                              GEOL=geolocation, RANGE_BIN=rangeBinNums, $
                              RN_FLAG=rainFlag, SCAN_TIME=scan_time_2a25, $
			      FRACTIONAL=frac_orbit_2a25)


.reset_session
scan_time_2b31=DBLARR(1)
frac_orbit_2b31=FLTARR(1)
file_2b31 = '/data/prsubsets/2B31/2B31.080819.61301.6.sub-GPMGV1.hdf.gz'
status = read_pr_2b31_fields( file_2b31, surfRain_2b31, SCAN_TIME=scan_time_2b31, FRACTIONAL=frac_orbit_2b31)
