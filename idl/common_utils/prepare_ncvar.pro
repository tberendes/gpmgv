;===============================================================================
;+
; Copyright © 2016, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; prepare_ncvar.pro         Morris/GPM GV/SAIC      December 2016
;
; DESCRIPTION
; Reads variables or attributes having the name 'thisNCobj' from the open netCDF
; file unit 'ncid'.  Optionally converts from byte array to string if BYTE is
; set.  Optionally resorts array variables along dimension 'dim2sort' using
; ordering specified by 'orderidx'.  Writes processed variables to 'target'.  If
; value for 'metaObj' is set, then also writes processed variable or attribute
; to the structure element whose tag is given by 'thisNCobj' unless overridden
; by 'tag'.
;
; If the binary keyword GLOBAL_ATTRIBUTE is set, then the object to be read is
; a 'global attribute' data type in the netCDF file, otherwise it is read as a
; 'variable' data type.  If the BYTE keyword is set then the value read from the
; netCDF file is asssumed to be character data in the form of an IDL BYTE array
; that needs to be converted to IDL STRING type.  THIS FUNCTION DOES NOT CHECK
; THAT THE VARIABLE READ WAS A BYTE ARRAY SO, IF THE BYTE KEYWORD IS SET, ANY
; VARIABLE READ FROM THE FILE WILL BE CONVERTED TO TYPE STRING OR AND ARRAY OF
; STRINGS IF THE CONVERSION IS VALID.  CALLER MUST KNOW HOW TO HANDLE THE netCDF
; VARIABLE TYPE.
;
; If an array of indices 'orderidx' that specify the order in which to resort an
; array variable read from the netCDF file is specified, then the data array is
; resorted along the dimension given by 'dim2sort' by a call to the included
; function sort_multi_d_array().
;
; RETURNS
; -------
; status               INT - Status of call to function, 0=success, 1=failure
;
; INTERNAL MODULES
; ----------------
; 1) sort_multi_d_array - called by prepare_ncvar() when array data need to be
;                         re-sorted along a specified dimension
; 2) prepare_ncvar      - external routine called by client program
;
; HISTORY
; -------
; 12/09/16  Morris/SAIC/GPM-GV
; - Created from code and logic taken from read_dpr_geo_match_netcdf.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS AT:
;       https://pmm.nasa.gov/contact
;-
;===============================================================================

; MODULE 2

FUNCTION sort_multi_d_array, orderidx, array2sort, sortdim

; re-sort a multi-dimensional array 'array2sort' along the dimension 'sortdim'
; in the order specified by 'orderidx'.  sortdim is 1-based, i.e., the first
; dimension is 1, 2nd is 2, ...

sz = SIZE(array2sort)
layers = N_ELEMENTS(orderidx)
IF ( layers EQ sz[sortdim] ) THEN BEGIN
   status=0

   CASE sz[0] OF
     2 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*]=temparr[orderidx[ndim],*]
                2 : array2sort[*,ndim]=temparr[*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     3 : BEGIN
           temparr=array2sort
           FOR ndim = 0, layers-1 DO BEGIN
             CASE sortdim OF
                1 : array2sort[ndim,*,*]=temparr[orderidx[ndim],*,*]
                2 : array2sort[*,ndim,*]=temparr[*,orderidx[ndim],*]
                3 : array2sort[*,*,ndim]=temparr[*,*,orderidx[ndim]]
             ENDCASE
           ENDFOR
         END
     ELSE : BEGIN
           print, 'ERROR from sort_multi_d_array() in read_dpr_geo_match_netcdf.pro:'
           print, 'Too many dimensions (', sz[0], ') in array to be sorted!'
           status=1
         END
   ENDCASE

ENDIF ELSE BEGIN
   print, 'ERROR from sort_multi_d_array() in prepare_ncvar.pro:'
   print, 'Size of array dimension over which to sort does not match number of sort indices!'
   status=1
ENDELSE

return, status
end

;===============================================================================
;
; MODULE 1

FUNCTION PREPARE_NCVAR, ncid, thisNCobj, target, STRUCT=metaObj, TAG=tag, $
                        GLOBAL_ATTRIBUTE=global, BYTE=byte2string, $
                        DIM2SORT=dim2sort, IDXSORT=orderidx

; read object named 'thisNCobj' from the netCDF file descriptor 'ncid'. Read as
; a regular variable unless GLOBAL_ATTRIBUTE is set, then read as a global
; attribute

IF KEYWORD_SET( global ) THEN NCDF_ATTGET, ncid, thisNCobj, ncvalue, /global $
                         ELSE NCDF_VARGET, ncid, thisNCobj, ncvalue

; reorder array values if orderidx is specified
IF N_ELEMENTS( orderidx ) NE 0 THEN BEGIN
   IF N_ELEMENTS( dim2sort ) NE 1 THEN BEGIN
      message, "Sorting requested, but sort dimension is unspecified.", /INFO
      return, 2
   ENDIF ELSE BEGIN
      sort_status = sort_multi_d_array( orderidx, ncvalue, dim2sort )
      IF (sort_status EQ 1) THEN return, sort_status
   ENDELSE
ENDIF

; convert read value from byte array to string if byte2string is set,
; and/or write processed value to I/O variable 'target'
IF KEYWORD_SET( byte2string ) THEN target=STRING(ncvalue) ELSE target=ncvalue

; if metaObj is specified, then it is a structure that the processed value
; is to be written to.  The tagname in the structure whose value is to be
; assigned is the name 'thisNCobj', unless overridden by the TAG keyword

IF N_ELEMENTS( metaObj ) NE 0 THEN BEGIN
  ; get the index of the tag/value pair in the structure we want to write to
   IF N_ELEMENTS(tag) GT 1 THEN BEGIN
      MESSAGE, "Parameter value 'tag' must be a scalar.", /INFO
      return, 2
   ENDIF
   IF N_ELEMENTS( tag ) EQ 1 THEN tag2get=tag ELSE tag2get=thisNCobj
  ; get the index number of the structure tag named 'tag2get'
   idx4pair = WHERE(TAG_NAMES(metaObj) EQ STRUPCASE(tag2get), nfound)
   IF nfound NE 1 THEN BEGIN
      message, "Cannot find tag '"+tag2get+"' in structure.', /INFO
      return, 2
   ENDIF ELSE BEGIN
     ; write the processed variable/attribute to the structure element
     ; at position 'idx4pair'
      metaObj.(idx4pair) = target
   ENDELSE
ENDIF

return, 0
END
