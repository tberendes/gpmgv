SCSTATUS = { SCSTATUS, $
  SCorientation : 0, $
  SClatitude : 0.0, $
  SClongitude : 0.0, $
  SCaltitude : 0.0, $
  FractionalGranuleNumber : 0.0d $
 }

SCANTIME = { SCANTIME, $
  Year : 0, $
  Month : 0b, $
  DayOfMonth : 0b, $
  Hour : 0b, $
  Minute : 0b, $
  Second : 0b, $
  MilliSecond : 0, $
  DayOfYear : 0, $
  SecondOfDay : 0.0d $
 }

L2AGPROFGMI_S1 = { L2AGPROFGMI_S1, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(221), $
  Longitude : FLTARR(221), $
  SCstatus : SCSTATUS, $
  pixelStatus : BYTARR(221), $
  retrievalType : BYTARR(221), $
  qualityFlag : BYTARR(221), $
  sunGlintAngle : BYTARR(221), $
  snowCoverIndex : BYTARR(221), $
  surfaceTypeIndex : BYTARR(221), $
  surfaceSkinTempIndex : INTARR(221), $
  totalColumnWaterIndex : BYTARR(221), $
  orographicLiftIndex : BYTARR(221), $
  databaseExpansionIndex : BYTARR(221), $
  surfacePrecipitation : FLTARR(221), $
  liquidPrecipFraction : FLTARR(221), $
  convectPrecipFraction : FLTARR(221), $
  probabilityOfPrecip : FLTARR(221), $
  mostLikelyPrecipitation : FLTARR(221), $
  precip1stTertial : FLTARR(221), $
  precip2ndTertial : FLTARR(221), $
  numOfSignificantProf : INTARR(221), $
  rainWaterPath : FLTARR(221), $
  cloudWaterPath : FLTARR(221), $
  mixedWaterPath : FLTARR(221), $
  iceWaterPath : FLTARR(221), $
  spare : INTARR(221), $
  spareIndex : BYTARR(221), $
  temp2mIndex : INTARR(221), $
  profileNumber : INTARR(5,221), $
  profileScale : FLTARR(5,221) $
 }

GPROFDHEADR = { GPROFDHEADR, $
  speciesDescription : BYTARR(12,5), $
  hgtTopLayer : FLTARR(28), $
  temperatureDescriptions : FLTARR(21), $
  clusterProfiles : FLTARR(5,21,28,100) $
 }

