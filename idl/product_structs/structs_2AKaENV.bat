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

L2AKaENV_HS_VERENV = { L2AKaENV_HS_VERENV, $
  airTemperature : FLTARR(88,24), $
  airPressure : FLTARR(88,24), $
  waterVapor : FLTARR(2,88,24), $
  cloudLiquidWater : FLTARR(2,88,24), $
  surfacePressure : FLTARR(24), $
  groundTemperature : FLTARR(24), $
  surfaceWind : FLTARR(2,24) $
 }

L2AKaENV_HS = { L2AKaENV_HS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(24), $
  Longitude : FLTARR(24), $
  VERENV : L2AKaENV_HS_VERENV $
 }

L2AKaENV_MS_VERENV = { L2AKaENV_MS_VERENV, $
  airTemperature : FLTARR(176,25), $
  airPressure : FLTARR(176,25), $
  waterVapor : FLTARR(2,176,25), $
  cloudLiquidWater : FLTARR(2,176,25), $
  surfacePressure : FLTARR(25), $
  groundTemperature : FLTARR(25), $
  surfaceWind : FLTARR(2,25) $
 }

L2AKaENV_MS = { L2AKaENV_MS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(25), $
  Longitude : FLTARR(25), $
  VERENV : L2AKaENV_MS_VERENV $
 }

L2AKaENV_SWATHS = { L2AKaENV_SWATHS, $
  MS : L2AKaENV_MS, $
  HS : L2AKaENV_HS $
 }

