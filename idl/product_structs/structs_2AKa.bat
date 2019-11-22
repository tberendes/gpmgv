L2AKa_HS_FLG = { L2AKa_HS_FLG, $
  flagEcho : BYTARR(88,24), $
  qualityData : LONARR(24), $
  flagSensor : 0b $
 }

L2AKa_HS_SLV = { L2AKa_HS_SLV, $
  flagSLV : BYTARR(88,24), $
  binEchoBottom : INTARR(24), $
  piaFinal : FLTARR(24), $
  sigmaZeroCorrected : FLTARR(24), $
  zFactorCorrected : INTARR(88,24), $
  zFactorCorrectedESurface : FLTARR(24), $
  zFactorCorrectedNearSurface : FLTARR(24), $
  paramDSD : INTARR(2,88,24), $
  precipRate : INTARR(88,24), $
  precipWaterIntegrated : FLTARR(2,24), $
  precipRateNearSurface : FLTARR(24), $
  precipRateESurface : FLTARR(24), $
  precipRateAve24 : FLTARR(24), $
  phaseNearSurface : BYTARR(24), $
  epsilon : INTARR(88,24) $
 }

L2AKa_HS_DSD = { L2AKa_HS_DSD, $
  phase : BYTARR(88,24), $
  binNode : INTARR(5,24) $
 }

L2AKa_HS_SRT = { L2AKa_HS_SRT, $
  PIAalt : FLTARR(6,24), $
  RFactorAlt : FLTARR(6,24), $
  PIAweight : FLTARR(6,24), $
  pathAtten : FLTARR(24), $
  reliabFactor : FLTARR(24), $
  reliabFlag : INTARR(24), $
  refScanID : INTARR(2,2,24) $
 }

L2AKa_HS_CSF = { L2AKa_HS_CSF, $
  flagBB : LONARR(24), $
  binBBPeak : INTARR(24), $
  binBBTop : INTARR(24), $
  binBBBottom : INTARR(24), $
  heightBB : FLTARR(24), $
  widthBB : FLTARR(24), $
  qualityBB : LONARR(24), $
  typePrecip : LONARR(24), $
  qualityTypePrecip : LONARR(24), $
  flagShallowRain : LONARR(24) $
 }

L2AKa_HS_VER = { L2AKa_HS_VER, $
  binZeroDeg : INTARR(24), $
  attenuationNP : INTARR(88,24), $
  piaNP : FLTARR(4,24), $
  sigmaZeroNPCorrected : FLTARR(24), $
  heightZeroDeg : FLTARR(24) $
 }

L2AKa_HS_PRE = { L2AKa_HS_PRE, $
  elevation : FLTARR(24), $
  landSurfaceType : LONARR(24), $
  localZenithAngle : FLTARR(24), $
  flagPrecip : LONARR(24), $
  binRealSurface : INTARR(24), $
  binStormTop : INTARR(24), $
  heightStormTop : FLTARR(24), $
  binClutterFreeBottom : INTARR(24), $
  sigmaZeroMeasured : FLTARR(24), $
  zFactorMeasured : INTARR(88,24), $
  ellipsoidBinOffset : FLTARR(24), $
  snRatioAtRealSurface : FLTARR(24) $
 }

L2AKa_HS_SCANSTATUS = { L2AKa_HS_SCANSTATUS, $
  dataQuality : 0b, $
  dataWarning : 0b, $
  missing : 0b, $
  modeStatus : 0b, $
  geoError : 0, $
  geoWarning : 0, $
  SCorientation : 0, $
  pointingStatus : 0, $
  acsModeMidScan : 0b, $
  targetSelectionMidScan : 0b, $
  operationalMode : 0b, $
  limitErrorFlag : 0b, $
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

L2AKa_HS = { L2AKa_HS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(24), $
  Longitude : FLTARR(24), $
  scanStatus : L2AKa_HS_SCANSTATUS, $
  PRE : L2AKa_HS_PRE, $
  VER : L2AKa_HS_VER, $
  CSF : L2AKa_HS_CSF, $
  SRT : L2AKa_HS_SRT, $
  DSD : L2AKa_HS_DSD, $
  SLV : L2AKa_HS_SLV, $
  FLG : L2AKa_HS_FLG $
 }

L2AKa_MS_FLG = { L2AKa_MS_FLG, $
  flagEcho : BYTARR(176,25), $
  qualityData : LONARR(25), $
  flagSensor : 0b $
 }

L2AKa_MS_SLV = { L2AKa_MS_SLV, $
  flagSLV : BYTARR(176,25), $
  binEchoBottom : INTARR(25), $
  piaFinal : FLTARR(25), $
  sigmaZeroCorrected : FLTARR(25), $
  zFactorCorrected : INTARR(176,25), $
  zFactorCorrectedESurface : FLTARR(25), $
  zFactorCorrectedNearSurface : FLTARR(25), $
  paramDSD : INTARR(2,176,25), $
  precipRate : INTARR(176,25), $
  precipWaterIntegrated : FLTARR(2,25), $
  precipRateNearSurface : FLTARR(25), $
  precipRateESurface : FLTARR(25), $
  precipRateAve24 : FLTARR(25), $
  phaseNearSurface : BYTARR(25), $
  epsilon : INTARR(176,25) $
 }

L2AKa_MS_DSD = { L2AKa_MS_DSD, $
  phase : BYTARR(176,25), $
  binNode : INTARR(5,25) $
 }

L2AKa_MS_SRT = { L2AKa_MS_SRT, $
  PIAalt : FLTARR(6,25), $
  RFactorAlt : FLTARR(6,25), $
  PIAweight : FLTARR(6,25), $
  pathAtten : FLTARR(25), $
  reliabFactor : FLTARR(25), $
  reliabFlag : INTARR(25), $
  refScanID : INTARR(2,2,25) $
 }

L2AKa_MS_CSF = { L2AKa_MS_CSF, $
  flagBB : LONARR(25), $
  binBBPeak : INTARR(25), $
  binBBTop : INTARR(25), $
  binBBBottom : INTARR(25), $
  heightBB : FLTARR(25), $
  widthBB : FLTARR(25), $
  qualityBB : LONARR(25), $
  typePrecip : LONARR(25), $
  qualityTypePrecip : LONARR(25), $
  flagShallowRain : LONARR(25) $
 }

L2AKa_MS_VER = { L2AKa_MS_VER, $
  binZeroDeg : INTARR(25), $
  attenuationNP : INTARR(176,25), $
  piaNP : FLTARR(4,25), $
  sigmaZeroNPCorrected : FLTARR(25), $
  heightZeroDeg : FLTARR(25) $
 }

L2AKa_MS_PRE = { L2AKa_MS_PRE, $
  elevation : FLTARR(25), $
  landSurfaceType : LONARR(25), $
  localZenithAngle : FLTARR(25), $
  flagPrecip : LONARR(25), $
  binRealSurface : INTARR(25), $
  binStormTop : INTARR(25), $
  heightStormTop : FLTARR(25), $
  binClutterFreeBottom : INTARR(25), $
  sigmaZeroMeasured : FLTARR(25), $
  zFactorMeasured : INTARR(176,25), $
  ellipsoidBinOffset : FLTARR(25), $
  snRatioAtRealSurface : FLTARR(25) $
 }

L2AKa_MS_SCANSTATUS = { L2AKa_MS_SCANSTATUS, $
  dataQuality : 0b, $
  dataWarning : 0b, $
  missing : 0b, $
  modeStatus : 0b, $
  geoError : 0, $
  geoWarning : 0, $
  SCorientation : 0, $
  pointingStatus : 0, $
  acsModeMidScan : 0b, $
  targetSelectionMidScan : 0b, $
  operationalMode : 0b, $
  limitErrorFlag : 0b, $
  FractionalGranuleNumber : 0.0d $
 }

L2AKa_MS = { L2AKa_MS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(25), $
  Longitude : FLTARR(25), $
  scanStatus : L2AKa_MS_SCANSTATUS, $
  PRE : L2AKa_MS_PRE, $
  VER : L2AKa_MS_VER, $
  CSF : L2AKa_MS_CSF, $
  SRT : L2AKa_MS_SRT, $
  DSD : L2AKa_MS_DSD, $
  SLV : L2AKa_MS_SLV, $
  FLG : L2AKa_MS_FLG $
 }

L2AKa_SWATHS = { L2AKa_SWATHS, $
  MS : L2AKa_MS, $
  HS : L2AKa_HS $
 }

