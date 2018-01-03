COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN
@pr_params.inc
@environs.inc
; initialize PR variables/arrays and read 1C21 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_1C21
   dbz_1c21=FLTARR(sample_range>1,1,num_range)
   landOceanFlag=INTARR(sample_range>1,RAYSPERSCAN)
   binS=INTARR(sample_range>1,RAYSPERSCAN)
   rayStart=INTARR(RAYSPERSCAN)
file_1c21 = '/tmp/PRv7test/1C21.20080515.59805.V7.HDF.gz'
;file_1c21 = '/data/prsubsets/1C21/1C21.080515.59805.6.sub-GPMGV1.hdf.gz'
   status = read_pr_1c21_fields( file_1c21, DBZ=dbz_1c21,  $
                                 OCEANFLAG=landOceanFlag,  $
                                 BinS=binS, RAY_START=rayStart )
