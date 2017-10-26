;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
;+

      pro distance_a_and_b, along, alat, blong, blat, dab

;     
; -- Give distance in units of km between point A(longitude, latitude)
;    and B(longitude, latitude) on the earth surface as both are not 
;    too far away.
;
;    Inputs:
;       along:   longitude (deg) of point A
;       alat :   latitude (deg) of point A
;       blong:   longitude (deg) of point B
;       blat :   latitude (deg) of point B
;
;    Output:
;       dab:   distance between A and B (km)
;
      pi=3.1415926535D
      r=6.3712e3    ;earth radius (km)
;      
      theta1=pi/2.-alat*pi/180.
      phi1=along*pi/180.
      theta2=pi/2.-blat*pi/180.
      phi2=blong*pi/180.
      cc1=sin(theta2)*cos(phi2)-sin(theta1)*cos(phi1)
      cc2=sin(theta2)*sin(phi2)-sin(theta1)*sin(phi1)
      cc3=cos(theta2)-cos(theta1)
      dab=r*sqrt(cc1^2+cc2^2+cc3^2)   ;(km)
;     
      end
