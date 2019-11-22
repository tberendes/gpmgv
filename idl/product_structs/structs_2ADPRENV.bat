L2ADPRENV_HS_VERENV = { L2ADPRENV_HS_VERENV, $
  airTemperature : FLTARR(88,24), $
  airPressure : FLTARR(88,24), $
  waterVapor : FLTARR(2,88,24), $
  cloudLiquidWater : FLTARR(2,88,24), $
  surfacePressure : FLTARR(24), $
  groundTemperature : FLTARR(24), $
  surfaceWind : FLTARR(2,24) $
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

L2ADPRENV_HS = { L2ADPRENV_HS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(24), $
  Longitude : FLTARR(24), $
  VERENV : L2ADPRENV_HS_VERENV $
 }

L2ADPRENV_NS_VERENV = { L2ADPRENV_NS_VERENV, $
  airTemperature : FLTARR(176,49), $
  airPressure : FLTARR(176,49), $
  waterVapor : FLTARR(2,176,49), $
  cloudLiquidWater : FLTARR(2,176,49), $
  surfacePressure : FLTARR(49), $
  groundTemperature : FLTARR(49), $
  surfaceWind : FLTARR(2,49) $
 }

L2ADPRENV_NS = { L2ADPRENV_NS, $
  ScanTime : SCANTIME, $
  Latitude : FLTARR(49), $
  Longitude : FLTARR(49), $
  VERENV : L2ADPRENV_NS_VERENV $
 }

L2ADPRENV_SWATHS = { L2ADPRENV_SWATHS, $
  NS : L2ADPRENV_NS, $
  HS : L2ADPRENV_HS $
 }

