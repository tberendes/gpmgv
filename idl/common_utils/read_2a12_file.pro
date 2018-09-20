;===============================================================================
;+
; Copyright © 2011, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
;    read_2a12_file.pro           Morris/SAIC/GPM_GV      Apr. 2011
;
; DESCRIPTION
; -----------
; Opens and reads caller-specified data fields from a TRMM PR 2A-12 HDF data
; file.  Data file must be read-ready (uncompressed).  The fully-qualified
; file pathname must be provided as the 'filename' mandatory parameter.
;
; - ScanTime is converted from individual date and time component values to unix
;   ticks (seconds since 1-1-1970 00:00:00 UTC).
;
; - Both Version 6 and 7 2A-12 file formats are supported.  Available variables
;   may differ between V6 and V7.  The following table maps the variables in the
;   function keyword parameters to the variable names in the V6 and V7 HDF files.
;   Variables not available in a given 2A12 file version are marked as 'N/A'.
;   If a request is made for a such a variable, a diagnostic message is printed
;   and the input value for the affected keyword parameter is left as-is.
;
;   Parameter        V6 Variable         V7 Variable           Qualifiers
;   =========================================================================
;   dataFlag         dataFlag            pixelStatus           (see Note 1,3)
;   rainFlag         rainFlag            N/A
;   surfaceType      surfaceFlag         surfaceType           (see Note 2,3)
;   surfaceRain      surfaceRain         surfacePrecipitation
;   surfRainLiquid      N/A              surfaceRain
;   convectRain      convectRain         convectPrecipitation
;   confidence       confidence          N/A
;   cldWater         cldWater            N/A
;   precipWater      precipWater         N/A
;   cldIce           cldIce              N/A
;   precipIce        precipIce           N/A
;   latentHeat       latentHeat          N/A
;   pixelStatus      dataFlag            pixelStatus           (see Note 1,3)
;   totPrecipWater      N/A              totalPrecipitableWater
;   windSpeed           N/A              windSpeed
;   cloudWaterPath      N/A              cloudWaterPath
;   rainWaterPath       N/A              rainWaterPath
;   iceWaterPath        N/A              rainWaterPath
;   sst                 N/A              seaSurfaceTemperature
;   chiSquared          N/A              chiSquared
;   PoP                 N/A              probabilityOfPrecip   (see Note 3)
;   freezingHeight      N/A              freezingHeight        (see Note 3)
;   dataQuality         N/A              dataQuality           (see Note 3)
;   qualityFlag         N/A              qualityFlag           (see Note 3)
;   landAmbiguousFlag   N/A              landAmbiguousFlag     (see Note 3)
;   landScreenFlag      N/A              landScreenFlag        (see Note 3)
;   oceanExtendedDbase  N/A              oceanExtendedDbase    (see Note 3)
;   oceanSearchRadius   N/A              oceanSearchRadius     (see Note 3)
;   sunGlintAngle       N/A              sunGlintAngle         (see Note 3)
;   freezingHeightIndex N/A              freezingHeightIndex   (see Note 3)
;   clusterNumber       N/A              clusterNumber         (see Note 3)
;   clusterScale        N/A              clusterScale
;   ===========================================================
;
;   Notes:
;   1) V6 dataFlag and V7 pixelStatus are interchangeable, in terms of data read
;      from files and returned for the keywords DATAFLAG and PIXELSTATUS
;   2) V6 surfaceFlag values are mapped to the corresponding V7 surfaceType
;   3) HDF variables of type BYTE are cast to signed INT to allow the negative
;      values as defined in the product documentation to be returned.
;
;
; HISTORY
; -------
; Apr 2011 - Bob Morris, GPM GV (SAIC)
; - Created.
; 07/13/11 - Bob Morris, GPM GV (SAIC)
; - Added freezingHeight to the variables able to be read from the 2A-12.
; 12/2/11 - Bob Morris, GPM GV (SAIC)
; - Added conversion of BYTE types to INT, and restoration of negative values
;   lost when IDL treats them as unsigned bytes: dataFlag, rainFlag,
;   surfaceType, pixelStatus, and PoP
; 04/10/12 - Bob Morris, GPM GV (SAIC)
; - Added error catching to the hdf_sd_getdata() calls to gracefully fail
;   in the event of bad SD data in an otherwise valid HDF file.
; 02/06/13 - Bob Morris, GPM GV (SAIC)
; - Added V7 fields: windSpeed, dataQuality, qualityFlag, landAmbiguousFlag,
;   landScreenFlag, oceanExtendedDbase, oceanSearchRadius, sunGlintAngle, 
;   freezingHeightIndex, clusterNumber, clusterScale
; 10/07/14  Morris/GPM GV/SAIC
; - Renamed NSPECIES to NSPECIES_TMI.
; 01/16/17 - Bob Morris, GPM GV (SAIC)
; - Added ST_STRUCT parameter to return a structure of arrays containing the
;   individual scan_time components, as requested by David Marks.
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

function read_2a12_file, filename, $
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
                         ST_STRUCT=st_struct_in, $
                         FRACTIONAL=frac_orbit_num, $
                         PRINT_ATTRIBUTES=print_attributes

   common sample, start_sample, sample_range, NLAYER_TMI, NPIXEL_TMI, NSPECIES_TMI

   if HDF_IsHDF (filename) then begin
      fileid=hdf_open(filename,/read)
      if ( fileid eq -1 ) then begin
         print, "In read_2a12_file.pro, error opening hdf file: ", filename
	 flag = 'Bad HDF File!'
	 return, flag
      endif
   endif else begin
      print, "In read_2a12_file.pro, tried to open non-hdf file: ", filename
      flag = 'Not HDF File!'
      return, flag
   endelse

   trmmversion = 0
   sd_id=HDF_SD_START(filename,/read)
   HDF_SD_FILEINFO, sd_id, nmfsds, attributes

  ; Display the number of SD type of files
   IF KEYWORD_SET(print_attributes) THEN print, "# of MFSD = ", nmfsds
   
   if nmfsds gt 0 then begin

      IF KEYWORD_SET(print_attributes) THEN BEGIN
         print, ' '
         print,"Information about MFHDF DataSets:"
         print, ' '
         print,"                          <---------------- Attribute Info ----------------->"
         print,"          NAME             IDL_Type   HDF_Type     Rank   Dimensions / Units"
         print,"-------------------------  -------- ------------   ----  -------------------"
         print
      ENDIF

      FSD='(A25,"  ",A8,"  ",I4,"  ",I4)'

      for i=0,nmfsds-1 do begin
      ;for i=0,1 do begin
         sds_id=HDF_SD_SELECT(sd_id,i)
         HDF_SD_GETINFO,sds_id,name=n,ndims=r,type=t,natts=nats,dims=dims,$
                        hdf_type=h,unit=u,format=fmt,label=label
         IF KEYWORD_SET(print_attributes) THEN BEGIN
             if r le 1 then FSD='(A25," ",A8," ",A12,3X,I4,3X,"[",I4,"] ",A)' $
             else FSD='(A25," ",A8," ",A12,3X,I4,3X,"["'+STRING(r-1)+'(I5,","),I5,"] ",A)'
          
             print,n,t,h,r,dims,u,FORMAT=FSD
         ENDIF

         ; Determine whether the file is version 6 or 7 by dataset names
         ; used for lat/lon information.  Geolocation is a 3-D array holding
         ; both variables in v6.  Latitude and longitude are separate 2-D
         ; arrays in v7.
          if n EQ 'geolocation' then begin
             nsample=dims(2)
             trmmversion = 6
          endif
          if n EQ 'Latitude' then begin
             nsample=dims(1)
             trmmversion = 7
          endif

          ;IF KEYWORD_SET(print_attributes) THEN BEGIN
          ;   print 
          ;   help,n,r,t,nats,dims,u
          ;   help,fmt,label,range
          ;ENDIF
          HDF_SD_ENDACCESS,sds_id
      endfor
      IF KEYWORD_SET(print_attributes) THEN BEGIN
         print,"-------------------------  -------- ------------   ----  -------------------"
         print
      ENDIF
   endif 

; Read data
 
if (START_SAMPLE eq 0) and (SAMPLE_RANGE le 1) then SAMPLE_RANGE=nsample

; ----------------------                
 
IF N_ELEMENTS(geolocation) GT 0 THEN BEGIN
   IF KEYWORD_SET(print_attributes) THEN $
      print, FORMAT='("TMI 2A12 version: ", I0)', trmmversion
   CASE trmmversion OF
     6: begin
          start = [0,0,start_sample]
          count = [2,NPIXEL_TMI,sample_range]
          stride = [1,1,1]

          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'geolocation'))
             HDF_SD_GETDATA, sds_id, geolocation, START=start, COUNT=count, $
                  STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_2a12_file.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: geolocation'
             return, flag
          ENDELSE
       end
     7: begin
          start = [0,start_sample]
          count = [NPIXEL_TMI,sample_range]
          stride = [1,1]
         ; get latitude and longitude and pack into a 3-D 'geolocation' array
         ; to match the v6 lat/lon data format
          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Latitude'))
             HDF_SD_GETDATA, sds_id, latitude, START=start, COUNT=count, $
                STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_2a12_file.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: Latitude'
             return, flag
          ENDELSE
          Catch, err_sts
          IF err_sts EQ 0 THEN BEGIN
             sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Longitude'))
             HDF_SD_GETDATA, sds_id, longitude, START=start, COUNT=count, $
                STRIDE=stride
          ENDIF ELSE BEGIN
             help,!error_state,/st
             Catch, /Cancel
             print, 'hdf_sd_getdata(): err=',err_sts
             HDF_Close, fileid
             print, "In read_2a12_file.pro, SD error in hdf file: ", filename
             flag = 'Bad SD: Longitude'
             return, flag
          ENDELSE

          lldims = SIZE(latitude)
          geolocation = FLTARR(2,lldims[1],lldims[2])
          IF KEYWORD_SET(print_attributes) THEN help, lldims, latitude, geolocation
          geolocation[0,*,*] = latitude
          geolocation[1,*,*] = longitude
        end
     ELSE : message, "Unable to determine product version."
   ENDCASE             
ENDIF

; -----------------------

IF N_ELEMENTS(dataFlag) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
     CASE trmmversion OF
          6 : field2get='dataFlag'
          7 : field2get='pixelStatus'
       ELSE : message, "Unable to determine product version."
     ENDCASE
     sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,field2get))
     HDF_SD_GETDATA, sds_id, dataFlag, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
    ; convert Unsigned BYTE to INT and restore negative values, if any
     dataFlag = FIX(dataFlag)
     idx2neg = WHERE( dataFlag GT 127, count2neg )
     IF count2neg GT 0 THEN dataFlag[idx2neg] = dataFlag[idx2neg] - 256
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a12_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: ' + field2get
      return, flag
   ENDELSE
ENDIF 

; -----------------------

MsgPre = "In read_2a12_file(): Unable to retrieve "
MsgPost = " for version: "

; -----------------------

IF N_ELEMENTS(rainFlag) GT 0 THEN BEGIN

   element='rainFlag'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : BEGIN
            Catch, err_sts
            IF err_sts EQ 0 THEN BEGIN
              sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rainFlag'))
              HDF_SD_GETDATA, sds_id, rainFlag, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
             ; convert Unsigned BYTE to INT and restore negative values, if any
              rainFlag = FIX(rainFlag)
              idx2neg = WHERE( rainFlag GT 127, count2neg )
              IF count2neg GT 0 THEN rainFlag[idx2neg] = rainFlag[idx2neg] - 256
            ENDIF ELSE BEGIN
               help,!error_state,/st
               Catch, /Cancel
               print, 'hdf_sd_getdata(): err=',err_sts
               HDF_Close, fileid
               print, "In read_2a12_file.pro, SD error in hdf file: ", filename
               flag = 'Bad SD: rainFlag'
               return, flag
            ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(surfaceType) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
     CASE trmmversion OF
          6 : field2get='surfaceFlag'
          7 : field2get='surfaceType'
       ELSE : message, "Unable to determine product version."
     ENDCASE
     sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,field2get))
     HDF_SD_GETDATA, sds_id, surfaceType, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
    ; convert Unsigned BYTE to INT and restore negative values, if any
     surfaceType = FIX(surfaceType)
     idx2neg = WHERE( surfaceType GT 127, count2neg )
     IF count2neg GT 0 THEN surfaceType[idx2neg] = surfaceType[idx2neg] - 256
     IF trmmversion EQ 6 THEN BEGIN
       ; map V6 types to V7: [ocean,land,coast,other] -> [ocean,land,coast,MISSING]
        v7_type_by_v6_value = [10,20,30,-99]
        surfaceType = v7_type_by_v6_value[surfaceType]
     END
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a12_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: ' + field2get
      return, flag
   ENDELSE
ENDIF 

; -----------------------

IF N_ELEMENTS(surfaceRain) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
     CASE trmmversion OF
          6 : field2get='surfaceRain'
          7 : field2get='surfacePrecipitation'
       ELSE : message, "Unable to determine product version."
     ENDCASE
     sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,field2get))
     HDF_SD_GETDATA, sds_id, surfaceRain, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a12_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: ' + field2get
      return, flag
   ENDELSE
ENDIF 

; -----------------------

IF N_ELEMENTS(surfRainLiquid) GT 0 THEN BEGIN

   element='surfRainLiquid'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'surfaceRain'))
                 HDF_SD_GETDATA, sds_id, surfRainLiquid, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: surfaceRain'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(convectRain) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
     CASE trmmversion OF
          6 : field2get='convectRain'
          7 : field2get='convectPrecipitation'
       ELSE : message, "Unable to determine product version."
     ENDCASE
     sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,field2get))
     HDF_SD_GETDATA, sds_id, convectRain, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a12_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: ' + field2get
      return, flag
   ENDELSE

ENDIF 

; -----------------------

IF N_ELEMENTS(windSpeed) GT 0 THEN BEGIN

   element='windSpeed'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'windSpeed'))
                 HDF_SD_GETDATA, sds_id, windSpeed, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: windSpeed'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(confidence) GT 0 THEN BEGIN

   element='confidence'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'confidence'))
                 HDF_SD_GETDATA, sds_id, confidence, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: confidence'
                 return, flag
              ENDELSE
         END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(cldWater) GT 0 THEN BEGIN

   element='cldWater'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NLAYER_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'cldWater'))
                 HDF_SD_GETDATA, sds_id, cldWater, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: cldWater'
                 return, flag
              ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(precipWater) GT 0 THEN BEGIN

   element='precipWater'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NLAYER_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'precipWater'))
                 HDF_SD_GETDATA, sds_id, precipWater, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: precipWater'
                 return, flag
              ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(cldIce) GT 0 THEN BEGIN

   element='cldIce'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NLAYER_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'cldIce'))
                 HDF_SD_GETDATA, sds_id, cldIce, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: cldIce'
                 return, flag
              ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(precipIce) GT 0 THEN BEGIN

   element='precipIce'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NLAYER_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'precipIce'))
                 HDF_SD_GETDATA, sds_id, precipIce, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: precipIce'
                 return, flag
              ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(latentHeat) GT 0 THEN BEGIN

   element='latentHeat'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NLAYER_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'latentHeat'))
                 HDF_SD_GETDATA, sds_id, latentHeat, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: latentHeat'
                 return, flag
              ENDELSE
            END
        7 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(pixelStatus) GT 0 THEN BEGIN

   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   Catch, err_sts
   IF err_sts EQ 0 THEN BEGIN
     CASE trmmversion OF
          6 : field2get='dataFlag'
          7 : field2get='pixelStatus'
       ELSE : message, "Unable to determine product version."
     ENDCASE
     sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,field2get))
     HDF_SD_GETDATA, sds_id, pixelStatus, START=start, COUNT=count, $
                STRIDE=stride, /noreverse
    ; convert Unsigned BYTE to INT and restore negative values, if any
     pixelStatus = FIX(pixelStatus)
     idx2neg = WHERE( pixelStatus GT 127, count2neg )
     IF count2neg GT 0 THEN pixelStatus[idx2neg] = pixelStatus[idx2neg] - 256
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      print, 'hdf_sd_getdata(): err=',err_sts
      HDF_Close, fileid
      print, "In read_2a12_file.pro, SD error in hdf file: ", filename
      flag = 'Bad SD: ' + field2get
      return, flag
   ENDELSE

ENDIF 

; -----------------------

IF N_ELEMENTS(totPrecipWater) GT 0 THEN BEGIN

   element='totalPrecipitableWater'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'totalPrecipitableWater'))
                 HDF_SD_GETDATA, sds_id, totPrecipWater, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: totalPrecipitableWater'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(cloudWaterPath) GT 0 THEN BEGIN

   element='cloudWaterPath'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'cloudWaterPath'))
                 HDF_SD_GETDATA, sds_id, cloudWaterPath, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: cloudWaterPath'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(rainWaterPath) GT 0 THEN BEGIN

   element='rainWaterPath'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'rainWaterPath'))
                 HDF_SD_GETDATA, sds_id, rainWaterPath, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: rainWaterPath'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(iceWaterPath) GT 0 THEN BEGIN

   element='iceWaterPath'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'iceWaterPath'))
                 HDF_SD_GETDATA, sds_id, iceWaterPath, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: iceWaterPath'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(sst) GT 0 THEN BEGIN

   element='seaSurfaceTemperature'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'seaSurfaceTemperature'))
                 HDF_SD_GETDATA, sds_id, sst, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: seaSurfaceTemperature'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(chiSquared) GT 0 THEN BEGIN

   element='chiSquared'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'chiSquared'))
                 HDF_SD_GETDATA, sds_id, chiSquared, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: chiSquared'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(PoP) GT 0 THEN BEGIN

   element='probabilityOfPrecip'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'probabilityOfPrecip'))
                 HDF_SD_GETDATA, sds_id, PoP, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 PoP= FIX(PoP)
                 idx2neg = WHERE( PoP GT 127, count2neg )
                 IF count2neg GT 0 THEN PoP[idx2neg] = PoP[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: probabilityOfPrecip'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(freezingHeight) GT 0 THEN BEGIN

   element='freezingHeight'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'freezingHeight'))
                 HDF_SD_GETDATA, sds_id, freezingHeight, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: freezingHeight'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(dataQuality) GT 0 THEN BEGIN

   element='dataQuality'
   start = [start_sample]
   count = [sample_range]
   stride = [1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'dataQuality'))
                 HDF_SD_GETDATA, sds_id, dataQuality, START=start, COUNT=count, $
                           STRIDE=stride ;, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 dataQuality= FIX(dataQuality)
                 idx2neg = WHERE( dataQuality GT 127, count2neg )
                 IF count2neg GT 0 THEN dataQuality[idx2neg] = dataQuality[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: dataQuality'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(qualityFlag) GT 0 THEN BEGIN

   element='qualityFlag'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'qualityFlag'))
                 HDF_SD_GETDATA, sds_id, qualityFlag, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 qualityFlag= FIX(qualityFlag)
                 idx2neg = WHERE( qualityFlag GT 127, count2neg )
                 IF count2neg GT 0 THEN qualityFlag[idx2neg] = qualityFlag[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: qualityFlag'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(landAmbiguousFlag) GT 0 THEN BEGIN

   element='landAmbiguousFlag'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'landAmbiguousFlag'))
                 HDF_SD_GETDATA, sds_id, landAmbiguousFlag, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 landAmbiguousFlag= FIX(landAmbiguousFlag)
                 idx2neg = WHERE( landAmbiguousFlag GT 127, count2neg )
                 IF count2neg GT 0 THEN landAmbiguousFlag[idx2neg] = landAmbiguousFlag[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: landAmbiguousFlag'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(landScreenFlag) GT 0 THEN BEGIN

   element='landScreenFlag'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'landScreenFlag'))
                 HDF_SD_GETDATA, sds_id, landScreenFlag, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 landScreenFlag= FIX(landScreenFlag)
                 idx2neg = WHERE( landScreenFlag GT 127, count2neg )
                 IF count2neg GT 0 THEN landScreenFlag[idx2neg] = landScreenFlag[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: landScreenFlag'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(oceanExtendedDbase) GT 0 THEN BEGIN

   element='oceanExtendedDbase'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'oceanExtendedDbase'))
                 HDF_SD_GETDATA, sds_id, oceanExtendedDbase, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 oceanExtendedDbase= FIX(oceanExtendedDbase)
                 idx2neg = WHERE( oceanExtendedDbase GT 127, count2neg )
                 IF count2neg GT 0 THEN oceanExtendedDbase[idx2neg] = oceanExtendedDbase[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: oceanExtendedDbase'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(oceanSearchRadius) GT 0 THEN BEGIN

   element='oceanSearchRadius'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'oceanSearchRadius'))
                 HDF_SD_GETDATA, sds_id, oceanSearchRadius, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 oceanSearchRadius= FIX(oceanSearchRadius)
                 idx2neg = WHERE( oceanSearchRadius GT 127, count2neg )
                 IF count2neg GT 0 THEN oceanSearchRadius[idx2neg] = oceanSearchRadius[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: oceanSearchRadius'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(sunGlintAngle) GT 0 THEN BEGIN

   element='sunGlintAngle'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'sunGlintAngle'))
                 HDF_SD_GETDATA, sds_id, sunGlintAngle, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 sunGlintAngle= FIX(sunGlintAngle)
                 idx2neg = WHERE( sunGlintAngle GT 127, count2neg )
                 IF count2neg GT 0 THEN sunGlintAngle[idx2neg] = sunGlintAngle[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: sunGlintAngle'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(freezingHeightIndex) GT 0 THEN BEGIN

   element='freezingHeightIndex'
   start = [start_sample,0]
   count = [sample_range,NPIXEL_TMI]
   stride = [1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'freezingHeightIndex'))
                 HDF_SD_GETDATA, sds_id, freezingHeightIndex, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 freezingHeightIndex= FIX(freezingHeightIndex)
                 idx2neg = WHERE( freezingHeightIndex GT 127, count2neg )
                 IF count2neg GT 0 THEN freezingHeightIndex[idx2neg] = freezingHeightIndex[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: freezingHeightIndex'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(clusterNumber) GT 0 THEN BEGIN

   element='clusterNumber'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NSPECIES_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'clusterNumber'))
                 HDF_SD_GETDATA, sds_id, clusterNumber, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
                ; convert Unsigned BYTE to INT and restore negative values, if any
                 clusterNumber= FIX(clusterNumber)
                 idx2neg = WHERE( clusterNumber GT 127, count2neg )
                 IF count2neg GT 0 THEN clusterNumber[idx2neg] = clusterNumber[idx2neg] - 256
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: clusterNumber'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF N_ELEMENTS(clusterScale) GT 0 THEN BEGIN

   element='clusterScale'
   start = [start_sample,0,0]
   count = [sample_range,NPIXEL_TMI,NSPECIES_TMI]
   stride = [1,1,1]

   CASE trmmversion OF
        6 : print, FORMAT='(3A0,I0)', MsgPre, element, MsgPost, trmmversion
        7 : BEGIN
              Catch, err_sts
              IF err_sts EQ 0 THEN BEGIN
                 sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'clusterScale'))
                 HDF_SD_GETDATA, sds_id, clusterScale, START=start, COUNT=count, $
                           STRIDE=stride, /noreverse
              ENDIF ELSE BEGIN
                 help,!error_state,/st
                 Catch, /Cancel
                 print, 'hdf_sd_getdata(): err=',err_sts
                 HDF_Close, fileid
                 print, "In read_2a12_file.pro, SD error in hdf file: ", filename
                 flag = 'Bad SD: clusterScale'
                 return, flag
              ENDELSE
            END
     ELSE : message, "Unable to determine product version."
   ENDCASE

ENDIF 

; -----------------------

IF ( trmmversion EQ 7 ) THEN BEGIN
   IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN
     ; get the FractionalGranuleNumber data
      start = [start_sample]
      count = [sample_range]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'FractionalGranuleNumber'))
         HDF_SD_GETDATA, sds_id, frac_orbit_num, START=start, COUNT=count, STRIDE=stride
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_2a12_file.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: FractionalGranuleNumber'
         return, flag
      ENDELSE
   ENDIF
   IF N_ELEMENTS(scan_time) GT 0 OR N_ELEMENTS(st_struct_in) GT 0 THEN BEGIN
     ; get the scanTime_sec data, in unix ticks
     ; must build from Year,Month,Day,Hour,Minute,Second,MilliSecond fields
      start = [start_sample]
      count = [sample_range]
      stride = [1]
      IF N_ELEMENTS(scan_time) EQ 0 THEN scan_time = DBLARR(1)  ; define a value
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         Year=FIX(scan_time)
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Year'))
         HDF_SD_GETDATA, sds_id, Year, START=start, COUNT=count, STRIDE=stride
        ; define Month array of dimensions of Year, and initialize to 0B
         Month=BYTE(Year) & Month[*]=0B
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Month'))
         HDF_SD_GETDATA, sds_id, Month, START=start, COUNT=count, STRIDE=stride
         DayOfMonth=BYTE(Year) & DayOfMonth[*]=0B
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'DayOfMonth'))
         HDF_SD_GETDATA, sds_id, DayOfMonth, START=start, COUNT=count, STRIDE=stride
         Hour=BYTE(Year) & Hour[*]=0B
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Hour'))
         HDF_SD_GETDATA, sds_id, Hour, START=start, COUNT=count, STRIDE=stride
         Minute=BYTE(Year) & Minute[*]=0B
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Minute'))
         HDF_SD_GETDATA, sds_id, Minute, START=start, COUNT=count, STRIDE=stride
         Second=BYTE(Year) & Second[*]=0B
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'Second'))
         HDF_SD_GETDATA, sds_id, Second, START=start, COUNT=count, STRIDE=stride
         MilliSecond=FIX(Year) & MilliSecond[*]=0
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'MilliSecond'))
         HDF_SD_GETDATA, sds_id, MilliSecond, START=start, COUNT=count, STRIDE=stride
         MilliSecondF=MilliSecond/1000.0
         scan_time = UNIXTIME( Year, Month, DayOfMonth, Hour, Minute, Second ) + MilliSecondF
         IF N_ELEMENTS(st_struct_in) GT 0 THEN BEGIN
           ; assemble the st_struct structure holding the arrays of the datetime elements
            st_struct = {        Year : FIX(Year), $
                                Month : FIX(Month), $
                           DayOfMonth : FIX(DayOfMonth), $
                                 Hour : FIX(Hour), $
                               Minute : FIX(Minute), $
                               Second : FIX(Second), $
                          MilliSecond : FIX(MilliSecond) }
            st_struct_in = st_struct
         ENDIF
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_2a12_file.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: Scan Time field(s)'
         return, flag
      ENDELSE
   ENDIF
   IF N_ELEMENTS(sc_lat_lon) GT 0 THEN BEGIN
     ; get the scLat and scLon data and merge to a 2-D array like geolocation
      start = [start_sample]
      count = [sample_range]
      stride = [1]
      Catch, err_sts
      IF err_sts EQ 0 THEN BEGIN
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'scLat'))
         HDF_SD_GETDATA, sds_id, sclat, START=start, COUNT=count, STRIDE=stride
         sds_id=HDF_SD_SELECT(sd_id,hdf_sd_nametoindex(sd_id,'scLon'))
         HDF_SD_GETDATA, sds_id, sclon, START=start, COUNT=count, STRIDE=stride
         lldims = SIZE(sclat)
         sc_lat_lon = FLTARR(2,lldims[1])
         IF KEYWORD_SET(print_attributes) THEN help, lldims, sclat, sc_lat_lon
         sc_lat_lon[0,*] = sclat
         sc_lat_lon[1,*] = sclon
      ENDIF ELSE BEGIN
         help,!error_state,/st
         Catch, /Cancel
         print, 'hdf_sd_getdata(): err=',err_sts
         HDF_Close, fileid
         print, "In read_2a12_file.pro, SD error in hdf file: ", filename
         flag = 'Bad SD: SC Lat-Lon field(s)'
         return, flag
      ENDELSE
   ENDIF
ENDIF

; -----------------------

HDF_SD_ENDACCESS,sds_id
HDF_SD_END,sd_id


IF ( trmmversion EQ 6 AND $
     (N_ELEMENTS(frac_orbit_num)+N_ELEMENTS(scan_time)) GT 0 ) THEN BEGIN
; -- Access Vdata
; Open the file for read and initialize the Vdata interface

    file_handle = hdf_open(filename,/read)
    
; Get the ID of the first Vdata in the file 

    vdata_ID = hdf_vd_getid(  file_handle, -1 )
    is_NOT_fakeDim = 1
    num_vdata = 0 
    
; Loop over Vdata 
    while (vdata_ID ne -1) and (is_NOT_fakeDim) do begin

; Attach to the vdata 
	vdata_H = hdf_vd_attach(file_handle,vdata_ID)

; Get vdata name
	hdf_vd_get, vdata_H, name=name,size= size, nfields = nfields
         
; Detach vdata
	hdf_vd_detach, vdata_H
       
; Check to see if this is a dummy
; Can't really explain why this happens but sometimes a dummy dimension
; gets returned as a Vdata name depending on the HDF file.  
	is_NOT_fakeDim = strpos(name,'fakeDim') eq -1

; Build up the list of Vdata names,sizes and number of fields 
	if (num_vdata eq 0) then begin
	    Vdata_name = name 
	    Vdata_size = size
	    Vdata_nfields = nfields
	    num_vdata = 1
	endif else if is_NOT_fakeDim then begin
	    Vdata_name = [Vdata_name,name]
            Vdata_size = [Vdata_size,size]
            Vdata_nfields = [Vdata_nfields,nfields]
	    num_vdata = num_vdata + 1
	endif
       
; Get ID of next Vdata
	vdata_ID = hdf_vd_getid( file_handle, vdata_ID )

    endwhile 

    IF KEYWORD_SET(print_attributes) THEN BEGIN
      ; Print out the list of names   
       print,''   
       print, 'List of Vdata names    Size (bytes)   Num. Fields'
       print, '-------------------------------------------------'
       for i = 0,num_vdata-1  do begin
   	  print, Vdata_name(i),Vdata_size(i),Vdata_nfields(i),$
	         format='(A18,I10,I14)'
       endfor
       print, '-------------------------------------------------'
    ENDIF

    IF N_ELEMENTS(frac_orbit_num) GT 0 THEN BEGIN

; Find the Scan status Vdata
      vdata_ID = hdf_vd_find(file_handle,'tmi_scan_status')

      if ( vdata_ID EQ 0 ) then begin  ;  status checking
        print, ""
        print, "In read_2a12_file(): Can't find tmi_scan_status vdata for frac_orbit_num."
        print, ""
      endif else begin
;    print, ""
;    print, "Getting frac_orbit_num vdata."
;    print, ""
       ; Attach to this Vdata
        vdata_H = hdf_vd_attach(file_handle,vdata_ID)

       ; Get the Vdata stats
        hdf_vd_get,vdata_H,name=name,fields=raw_field

       ; Separate the fields
        fields = str_sep(raw_field,',')
        IF KEYWORD_SET(print_attributes) THEN BEGIN
           print, ""
           print, "Fields in tmi_scan_status:"
           print, fields
           print, ""
        ENDIF
       ; Read the Vdata, returns the number of records
       ; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)
       ; IDL will issue a warning to remind you there are mixed data types in
       ; the array
        nscan = hdf_vd_read(vdata_h,data)
       ; Could have just read in the fractional orbit number with the
       ; fields keyword but this shows you how to extract the data from the 
       ; full record BYTE array.

       ; Make up an array for the fractional orbit number
        frac_orbit_num = fltarr(nscan)

       ; Loop over the records and pull out the fractional orbit number   
        for i = 0,nscan-1 do begin
       ; We know that the frac_orbit_number starts at position 17 in the byte array
          frac_orbit_num(i) = float(data(*,i),17)
        endfor
  
        hdf_vd_detach, Vdata_H   ; Detach from the Vdata
  
      endelse
    ENDIF

    IF N_ELEMENTS(scan_time) GT 0 OR N_ELEMENTS(st_struct_in) GT 0 THEN BEGIN

; get the scantime vdata and convert to ticks

      vdata_ID = hdf_vd_find(file_handle,'scan_time')
      if ( vdata_ID EQ 0 ) then begin  ;  status checking
        print, ""
        print, "In read_2a12_file(): Can't find scan_time vdata."
        print, ""
      endif else begin
;        print, ""
;        print, "Getting scan_time vdata."
;        print, ""
        vdata_H = hdf_vd_attach(file_handle,vdata_ID)
        nscan = hdf_vd_read(vdata_H, scan_time)
        hdf_vd_detach, Vdata_H   ; Detach from the Vdata
;        help, scan_time
        year = REFORM( scan_time[1,*]*256 + scan_time[0,*] )
        month = REFORM( scan_time[2,*] )
        dayofmonth = REFORM( scan_time[3,*] )
        hour = REFORM( scan_time[4,*] )
        minute = REFORM( scan_time[5,*] )
        second = REFORM( scan_time[6,*] )
        dayofyear = REFORM( scan_time[8,*]*256 + scan_time[7,*] )
        scan_time = UNIXTIME( Year, Month, DayOfMonth, Hour, Minute, Second )
        IF N_ELEMENTS(st_struct_in) GT 0 THEN BEGIN
           ; define and initialize a MilliSecond array to all zeroes
            MilliSecond = FIX(second)
            MilliSecond[*] = 0
           ; assemble the st_struct structure holding the arrays of the datetime elements
            st_struct = {        Year : FIX(Year), $
                                Month : FIX(Month), $
                           DayOfMonth : FIX(DayOfMonth), $
                                 Hour : FIX(Hour), $
                               Minute : FIX(Minute), $
                               Second : FIX(Second), $
                          MilliSecond : FIX(MilliSecond) }
            st_struct_in = st_struct
         ENDIF
      endelse
    ENDIF

    IF N_ELEMENTS(sc_lat_lon) GT 0 THEN BEGIN
     ; get the scLat and scLon data and merge to a 2-D array like geolocation

      vdata_ID = hdf_vd_find(file_handle,'navigation')
      if ( vdata_ID EQ 0 ) then begin  ;  status checking
        print, ""
        print, "In read_2a12_file(): Can't find navigation vdata."
        print, ""
      endif else begin
        vdata_H = hdf_vd_attach(file_handle,vdata_ID)

       ; Get the Vdata stats
        hdf_vd_get,vdata_H,name=name,fields=raw_field

       ; Separate the fields
        fields = str_sep(raw_field,',')
        IF KEYWORD_SET(print_attributes) THEN BEGIN
           print, ""
           print, "Fields in navigation Vdata:"
           print, fields
           print, ""
        ENDIF
       ; Read the Vdata, returns the number of records
       ; The data for all records is returned in a BYTE ARRAY of (record_size,nscans)
       ; IDL will issue a warning to remind you there are mixed data types in
       ; the array
        nscan = hdf_vd_read(vdata_H, navigation)
        hdf_vd_detach, Vdata_H   ; Detach from the Vdata

        sc_lat_lon = FLTARR(2,nscan)
        IF KEYWORD_SET(print_attributes) THEN help, nscan, navigation, sc_lat_lon
       ; Loop over the records and pull out the latitude and longitude  
        for i = 0,nscan-1 do begin
       ; We know that the lat (lon) starts at position 24 (28) in the byte array
          sc_lat_lon[0,i] = float(navigation(*,i),24)
          sc_lat_lon[1,i] = float(navigation(*,i),28)
        endfor
      endelse
    ENDIF

    hdf_close,fileid
ENDIF

flag = 'OK'
return, flag

end
