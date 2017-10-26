;+
; AUTHOR:
;       Liang Liao
;       Caelum Research Corp.
;       Code 975, NASA/GSFC
;       Greenbelt, MD 20771
;       Phone: 301-614-5718
;       E-mail: lliao@priam.gsfc.nasa.gov
; MODIFIED:
;       Oct 2006 - Bob Morris, GPM GV (SAIC)
;       - Dropped groundSite common usage, passed all needed parameters
;+

      pro coordinate_b_to_a, siteLong, siteLat, obsLong, obsLat, XX, YY
;      common groundSite, siteID, siteLong, siteLat

; -- Determine XX (east-west) and YY (north-south) distances from
;    radar site A to a random lat/lon point B by projecting onto a
;    unit vector aligned at radar site.  Ignore most of the rest of
;    this documentation/commented stuff.  Seems like a long way to
;    go just to get x and y on a local-centered coord system.
;    Morris/SAIC July 06.

; -- Determining the distance between 1 deg. box of long. and lat.
;    by changing long. and lat. by 1 deg.
;
      pi=3.1415926535D
      r=6.3712e3    ;earth radius (km)     

;     Print,'Distance along longitude in 1 deg. =', dLong
;     Print,'Distance along latitude in 1 deg. =', dLat

;      
; -- Determine the unit vector (uv) along the east direction, i.e.,
;    phi direction in terms of earth coordinate, at the site (locally)
;    by increasing 1 deg. of longitude as well as the north direction,
;    i.e., -theta direction, by decreasing 1 deg. of latitude or increasing
;    1 deg. of latitude.
;
;    The coordinate is described in a way where the site on the ground
;    is at point A, the tarket of satellite is B.
;
      thetaA=pi/2.-siteLat*pi/180.
      phiA=siteLong*pi/180.
      
      thetaAp1=pi/2.-(siteLat+1.)*pi/180.   ; 1 deg. increment of latitude
      phiAp1=(siteLong+1.)*pi/180.          ; 1 deg. increment of longitude
      
      xA = r*sin(thetaA)*cos(phiA)   ; Point A coordinate
      yA = r*sin(thetaA)*sin(phiA)
      zA = r*cos(thetaA)
      
;    The unit vector of A along the east is expressed in terms of earth coord.

      distance_a_and_b, siteLong, siteLat, siteLong+1., siteLat, dLong
      xU = r*sin(thetaA)*cos(phiAp1)
      yU = r*sin(thetaA)*sin(phiAp1)
      zU = r*cos(thetaA)
       
      XuvLong = (xU-xA)/dLong
      YuvLong = (yU-yA)/dLong
      ZuvLong = (zU-zA)/dLong
      
;    The unit vector of A along the north is expressed in terms of earth
;    coordinates.
      
      distance_a_and_b, siteLong, siteLat, siteLong, siteLat+1., dLat
      xU = r*sin(thetaAp1)*cos(phiA)
      yU = r*sin(thetaAp1)*sin(phiA)
      zU = r*cos(thetaAp1)
      
      XuvLat = (xU-xA)/dLat
      YuvLat = (yU-yA)/dLat
      ZuvLat = (zU-zA)/dLat
;
; -- Vector AB
;
      thetaB=pi/2.-obsLat*pi/180.
      phiB=obsLong*pi/180.
      
      xB = r*sin(thetaB)*cos(phiB)   ; Point B coordinate
      yB = r*sin(thetaB)*sin(phiB)
      zB = r*cos(thetaB)
      
      xAB = xB-xA
      yAB = yB-yA
      zAB = zB-zA
;
; -- Project vector AB onto unit vector of A along the east and north
;
      XX = xAB*XuvLong+yAB*YuvLong+zAB*ZuvLong
      YY = xAB*XuvLat+yAB*YuvLat+zAB*ZuvLat 
      
;     print, 'XX =', XX, '    YY =',YY
;     print, 'Distance between A and B =', sqrt(XX^2+YY^2)        
      
      end
      
@distance_a_and_b.pro
