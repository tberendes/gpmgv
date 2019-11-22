;
;        HM_CONST.inc - This file defines hydromet constants for IDL
;                       applications.
;
;   DESCRIPTION
;        This unit provides compiler level visibility to hm constants 
;	for the Advanced Weather Interactive Processing System.
;
;	They were organized in alphabetical order for ease of reading.  
;
;***********************************************************************

;  gridpoint missing value indicators...   
	RMISS        = -9.999e37
	IMISS        = -999999999        
	DMISS        = -9.999d37
   
;  value of PI from mpProjection.h in DWB
	HM_PI        = 3.14159265358979323846
   
	DEG2RAD      = HM_PI/180.0
	RAD2DEG      = 180.0/HM_PI
	TWO_PI       = HM_PI * 2.0
	PI_OVER_2    = HM_PI / 2.0
;   in meters  
      REARTH = 6.37120e+6

;  in radians per second  
      HM_OMEGA = 7.2921e-5
      HM_2OMEGA = HM_OMEGA*2.0

;  g in meters per second per second 
      HM_GRAVITY = 9.80616

;  Dry air gas constant - Rd  
      HM_RD = 2.8704e+2
;  in J per kg per K  
;  Specific heat of dry air at constant pressure 
      HM_CP = 1.0046e+3
;  in J per kg per K  

;  Specific heat of dry air at constant volume 
      HM_CV = 7.1760e+2
;  in J per kg per K  

;  Specific heat of water vapor at constant pressure 
      HM_CVAP = 1.8460e+3
;  in J per kg per K  

;  specific heat capacity of liquid water 
      HM_CLIQ = 4.1855e+3
;  in J per kg per K  

;  Water vapor gas constant 
      HM_RV = 4.6150e+2
;  in J per kg per K  

;  Latent heat of vaporization of water at 0 deg C 
      HM_LV = 2.5000e+6
;  in J per kg  

;  Latent heat of fusion of water at 0 deg C 
      HM_LF = 3.3358e+5
;  in J per kg  

;  Saturation vapor pressure at the triple point 
      HM_ES = 6.107799961e+2
;  in Pa  

;  Solar constant 
      HM_SOLAR = 1.3533e+3
;  in J per m sq per s  

;  Stefan-Boltzmann constant 
      HM_STEF_BOLTZ = 5.6730e-8
;  in J per m sq per K 4th per s  

;  U.S. Standard Atmosphere Lapse Rate 
      HM_US_LAPSE = 6.500e-3
;  in deg per m  

;  U.S. Standard Atmosphere Surface Pressure 
      HM_US_SFC_PRES = 1.101325e+5
;  in deg per m  

;  U.S. Standard Atmosphere Surface Density 
      HM_US_SFC_DENSITY = 1.2250
;  in kg per m cubed  

;  U.S. Standard Atmosphere Surface Temperature 
      HM_US_SFC_TEMP = 288.15
;  in K  

;  Ratio of Rd/Cp 
      HM_RD_TO_CP = 2./7.
;  unitless  

;  Ratio of Rd/Rv 
      HM_RD_TO_RV = .62197
;  unitless  

;  Universal Gas Constant 
      HM_UNV_GAS_CONST = 8.31432
;  in J per mol per K  

;  Molecular weight of dry air 
      HM_MD = 28.9644
;  ?  

;  Molecular weight of water vapor 
      HM_MV = 18.0153
;  ?  

;  Coriolis parameter at 45 deg 
      HM_CORIOLIS = 1.0313e-4
;  per s  

;  Increment to add on either side of a double
;  to make sure that it is within the float range 
      HM_EPSILON = 1.0e-5
;  dimensionless  

;    Lower bounds for numerical caculations 
;  deg K   
      HM_LOW_TEMP_LIMIT = 30.
;  mb      
      HM_LOW_PRES_LIMIT = 1.E-3
;  g/kg    
      HM_LOW_RMIX_LIMIT = 1.E-10
;  mb      
      HM_LOW_VAPOR_LIMIT = 1.E-10
;  percent 
      HM_LOW_RH_LIMIT = 1.E-5

;         Temperature parameters. 

;  deg K   
      HM_ZERO_CELSIUS = 273.15

;    Vapor Pressure Constants
;
;    From GEMPAK using Bolton's empirical formulas converting
;    between dewpoint to mixing ratio
;    Note HM_BVP4 = HM_BVP3 * LOG(HM_BVP1)
;         HM_BVP5 = HM_BVP2 - LOG(HM_BVP1) 

;  mb       
      HM_BVP1 = 6.112
;  dimensionless 
      HM_BVP2 = 17.67
;  deg C 
      HM_BVP3 = 243.5
;  deg C 
      HM_BVP4 = 440.8
;  dimensionless 
      HM_BVP5 = 19.48

;        Equivalent Potential Temperature constants 
;        From Bolton to compute THETA_E  

;  dimensionless 
      HM_BTM = 0.28
;  deg K 
      HM_BTL1 = 55.
;  deg K 
      HM_BTL2 = 2840.
;  deg K 
      HM_BTE1 = 3.376
;  dimensionless 
      HM_BTE2 = 0.00254
;  dimensionless 
      HM_BTE3 = 0.81

;     Non-Ideal Gas Law correction  
;     From GEMPAK from University of Washington Green Sheet 

;  dimensionless 
      HM_UWGL1 = 1.001
;  mb 
      HM_UWGL2 = 100.
;  mb 
      HM_UWGL3 = 900.
;  dimensionless 
      HM_UWGL4 = .0034


;      Maximum Level of RH Fields sent by all models 

; mb 
      HM_RHTOP = 300.
