L2BCMB_MS_INPUT = { L2BCMB_MS_INPUT, $
  surfaceElevation : FLTARR(25), $
  surfaceType : LONARR(25), $
  localZenithAngle : FLTARR(25), $
  precipitationFlag : LONARR(2,25), $
  surfaceRangeBin : INTARR(2,25), $
  lowestClutterFreeBin : INTARR(2,25), $
  ellipsoidBinOffset : FLTARR(2,25), $
  stormTopBin : INTARR(2,25), $
  stormTopAltitude : FLTARR(2,25), $
  precipitationType : LONARR(25), $
  precipTypeQualityFlag : LONARR(25), $
  piaEffective : FLTARR(2,25), $
  piaEffectiveSigma : FLTARR(2,25), $
  piaEffectiveReliabFlag : INTARR(2,25) $
 }

L2BCMB_MS_SCANSTATUS = { L2BCMB_MS_SCANSTATUS, $
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

L2BCMB_MS = { L2BCMB_MS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(25), $
  Longitude : FLTARR(25), $
  scanStatus : L2BCMB_MS_SCANSTATUS, $
  Input : L2BCMB_MS_INPUT, $
  surfaceAirPressure : FLTARR(25), $
  surfaceAirTemperature : FLTARR(25), $
  surfaceVaporDensity : FLTARR(25), $
  skinTemperature : FLTARR(25), $
  envParamNode : INTARR(10,25), $
  airPressure : FLTARR(10,25), $
  airTemperature : FLTARR(10,25), $
  vaporDensity : FLTARR(10,25), $
  cloudLiqWaterCont : FLTARR(88,25), $
  cloudIceWaterCont : FLTARR(88,25), $
  phaseBinNodes : INTARR(5,25), $
  PSDparamLowNode : INTARR(9,25), $
  precipPSDparamLow : FLTARR(2,9,25), $
  precipPSDparamHigh : FLTARR(88,25), $
  precipLiqWaterCont : FLTARR(88,25), $
  precipLiqWaterContSigma : FLTARR(88,25), $
  precipRate : FLTARR(88,25), $
  precipRateSigma : FLTARR(88,25), $
  liqMassFracTrans : FLTARR(5,25), $
  liqRateFracTrans : FLTARR(5,25), $
  iceDensity : FLTARR(2,25), $
  surfPrecipRate : FLTARR(25), $
  surfPrecipRateSigma : FLTARR(25), $
  surfLiqRateFrac : FLTARR(25), $
  tenMeterWindSpeed : FLTARR(25), $
  surfEmissivity : FLTARR(15,25), $
  simulatedBrightTemp : FLTARR(15,25), $
  pia : FLTARR(2,25), $
  correctedReflectFactor : FLTARR(2,88,25) $
 }

L2BCMB_NS_INPUT = { L2BCMB_NS_INPUT, $
  surfaceElevation : FLTARR(49), $
  surfaceType : LONARR(49), $
  localZenithAngle : FLTARR(49), $
  precipitationFlag : LONARR(49), $
  surfaceRangeBin : INTARR(49), $
  lowestClutterFreeBin : INTARR(49), $
  ellipsoidBinOffset : FLTARR(49), $
  stormTopBin : INTARR(49), $
  stormTopAltitude : FLTARR(49), $
  precipitationType : LONARR(49), $
  precipTypeQualityFlag : LONARR(49), $
  piaEffective : FLTARR(49), $
  piaEffectiveSigma : FLTARR(49), $
  piaEffectiveReliabFlag : INTARR(49) $
 }

L2BCMB_NS_SCANSTATUS = { L2BCMB_NS_SCANSTATUS, $
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

L2BCMB_NS = { L2BCMB_NS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(49), $
  Longitude : FLTARR(49), $
  scanStatus : L2BCMB_NS_SCANSTATUS, $
  Input : L2BCMB_NS_INPUT, $
  surfaceAirPressure : FLTARR(49), $
  surfaceAirTemperature : FLTARR(49), $
  surfaceVaporDensity : FLTARR(49), $
  skinTemperature : FLTARR(49), $
  envParamNode : INTARR(10,49), $
  airPressure : FLTARR(10,49), $
  airTemperature : FLTARR(10,49), $
  vaporDensity : FLTARR(10,49), $
  cloudLiqWaterCont : FLTARR(88,49), $
  cloudIceWaterCont : FLTARR(88,49), $
  phaseBinNodes : INTARR(5,49), $
  PSDparamLowNode : INTARR(9,49), $
  precipPSDparamLow : FLTARR(2,9,49), $
  precipPSDparamHigh : FLTARR(88,49), $
  precipLiqWaterCont : FLTARR(88,49), $
  precipLiqWaterContSigma : FLTARR(88,49), $
  precipRate : FLTARR(88,49), $
  precipRateSigma : FLTARR(88,49), $
  liqMassFracTrans : FLTARR(5,49), $
  liqRateFracTrans : FLTARR(5,49), $
  iceDensity : FLTARR(2,49), $
  surfPrecipRate : FLTARR(49), $
  surfPrecipRateSigma : FLTARR(49), $
  surfLiqRateFrac : FLTARR(49), $
  tenMeterWindSpeed : FLTARR(49), $
  surfEmissivity : FLTARR(15,49), $
  simulatedBrightTemp : FLTARR(15,49), $
  pia : FLTARR(49), $
  correctedReflectFactor : FLTARR(88,49) $
 }

L2BCMB_SWATHS = { L2BCMB_SWATHS, $
  NS : L2BCMB_NS, $
  MS : L2BCMB_MS $
 }

