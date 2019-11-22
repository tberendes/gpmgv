L2AKu_FLG = { L2AKu_FLG, $
  flagEcho : BYTARR(176,49), $
  qualityData : LONARR(49), $
  flagSensor : 0b $
 }

L2AKu_SLV = { L2AKu_SLV, $
  flagSLV : BYTARR(176,49), $
  binEchoBottom : INTARR(49), $
  piaFinal : FLTARR(49), $
  sigmaZeroCorrected : FLTARR(49), $
  zFactorCorrected : INTARR(176,49), $
  zFactorCorrectedESurface : FLTARR(49), $
  zFactorCorrectedNearSurface : FLTARR(49), $
  paramDSD : INTARR(2,176,49), $
  precipRate : INTARR(176,49), $
  precipWaterIntegrated : FLTARR(2,49), $
  precipRateNearSurface : FLTARR(49), $
  precipRateESurface : FLTARR(49), $
  precipRateAve24 : FLTARR(49), $
  phaseNearSurface : BYTARR(49), $
  epsilon : INTARR(176,49) $
 }

L2AKu_DSD = { L2AKu_DSD, $
  phase : BYTARR(176,49), $
  binNode : INTARR(5,49) $
 }

L2AKu_SRT = { L2AKu_SRT, $
  PIAalt : FLTARR(6,49), $
  RFactorAlt : FLTARR(6,49), $
  PIAweight : FLTARR(6,49), $
  pathAtten : FLTARR(49), $
  reliabFactor : FLTARR(49), $
  reliabFlag : INTARR(49), $
  refScanID : INTARR(2,2,49) $
 }

L2AKu_CSF = { L2AKu_CSF, $
  flagBB : LONARR(49), $
  binBBPeak : INTARR(49), $
  binBBTop : INTARR(49), $
  binBBBottom : INTARR(49), $
  heightBB : FLTARR(49), $
  widthBB : FLTARR(49), $
  qualityBB : LONARR(49), $
  typePrecip : LONARR(49), $
  qualityTypePrecip : LONARR(49), $
  flagShallowRain : LONARR(49) $
 }

L2AKu_VER = { L2AKu_VER, $
  binZeroDeg : INTARR(49), $
  attenuationNP : INTARR(176,49), $
  piaNP : FLTARR(4,49), $
  sigmaZeroNPCorrected : FLTARR(49), $
  heightZeroDeg : FLTARR(49) $
 }

L2AKu_PRE = { L2AKu_PRE, $
  elevation : FLTARR(49), $
  landSurfaceType : LONARR(49), $
  localZenithAngle : FLTARR(49), $
  flagPrecip : LONARR(49), $
  binRealSurface : INTARR(49), $
  binStormTop : INTARR(49), $
  heightStormTop : FLTARR(49), $
  binClutterFreeBottom : INTARR(49), $
  sigmaZeroMeasured : FLTARR(49), $
  zFactorMeasured : INTARR(176,49), $
  ellipsoidBinOffset : FLTARR(49), $
  snRatioAtRealSurface : FLTARR(49) $
 }

L2AKu_SCANSTATUS = { L2AKu_SCANSTATUS, $
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

L2AKu_NS = { L2AKu_NS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(49), $
  Longitude : FLTARR(49), $
  scanStatus : L2AKu_SCANSTATUS, $
  PRE : L2AKu_PRE, $
  VER : L2AKu_VER, $
  CSF : L2AKu_CSF, $
  SRT : L2AKu_SRT, $
  DSD : L2AKu_DSD, $
  SLV : L2AKu_SLV, $
  FLG : L2AKu_FLG $
 }

