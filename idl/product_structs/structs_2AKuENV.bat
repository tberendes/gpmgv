L2AKuENV_VERENV = { L2AKuENV_VERENV, $
  airTemperature : FLTARR(176,49), $
  airPressure : FLTARR(176,49), $
  waterVapor : FLTARR(2,176,49), $
  cloudLiquidWater : FLTARR(2,176,49), $
  surfacePressure : FLTARR(49), $
  groundTemperature : FLTARR(49), $
  surfaceWind : FLTARR(2,49) $
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

L2AKuENV_NS = { L2AKuENV_NS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(49), $
  Longitude : FLTARR(49), $
  VERENV : L2AKuENV_VERENV $
 }

