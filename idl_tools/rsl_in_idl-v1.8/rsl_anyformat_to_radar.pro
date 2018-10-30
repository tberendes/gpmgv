; Copyright (C) 2003  NASA/TRMM Satellite Validation Office
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;**************************************************************************
;+
; rsl_anyformat_to_radar
;
; This function determines the format of the input radar file and calls the
; appropriate function to read data into the radar structure. If successful,
; a radar structure is returned, otherwise, function returns value of -1.
; 
; Syntax:
;     radar = rsl_anyformat_to_radar(radarfile [, siteID-or-header]
;                 [, /CATCH_ERROR] [, ERROR=variable] [, /KEEP_RADAR]
;                 [, /QUIET] [, VOS_NUMBER=vosnumber])
;
; Inputs:
;     radarfile:  string containing name of radar file.
;     siteID-or-header:
;         optional argument for WSR-88D processing: It is a string containing
;         either the 4-character WSR-88D site ID or the name of a WSR-88D
;         header file.  If omitted, program will attempt to get site ID from
;         file name.
;		        
; Keyword parameters:
;     CATCH_ERROR:
;         Starting with version 1.4, this keyword is set by default.  It
;         initiates an error handler that returns control to the calling
;         program if an error occurs.  Set CATCH_ERROR to 0 to turn off
;         error handler.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, -1 is returned.
;     QUIET:
;         Set this keyword to turn off progress reporting.
;     ERROR:
;         Set this keyword to a variable to return the error status.
;         A value of 1 is returned for error, 0 otherwise.
;     VOS_NUMBER:
;         For TSDIS Level 1 HDF only, the number (1 to n) of the volume scan
;         to be read from HDF.  Default is the first (VOS_NUMBER = 1). 
;
; Written by:  Bart Kelley, GMU, January 2003
; Based on the C language program RSL_anyformat_to_radar by John Merritt.
;**************************************************************************
;-

function get_portable_format_filetype, iunit

; Determine if file is CfRadial or D3R.  Return file type as a string.
; If file type cannot be determined, return the string 'unknown'.

filetype = 'unknown'
fileinfo = fstat(iunit)
cfid = ncdf_open(fileinfo.name, /nowrite)
info = ncdf_inquire(cfid)
; Search global attributes for an identifying string.
for i=0, info.ngatts-1 do begin
    name = ncdf_attname(cfid,i,/global)
    if stregex(name,'convention',/boolean,/fold_case) then begin
        ncdf_attget,cfid,name,value,/global
        if stregex(value,'cf.*radial',/boolean,/fold_case) then begin
            filetype = 'cfradial_file'
            break
        endif
    endif else if stregex(name,'radar.*name',/boolean,/fold_case) then begin
        ncdf_attget,cfid,name,value,/global
        if stregex(value,'d3r',/boolean,/fold_case) then begin
            filetype = 'd3r_file'
            break
        endif
    endif
endfor
ncdf_close, cfid

return, filetype
end


;******************************;
;         rsl_filetype         ;
;******************************;

function rsl_filetype, infile

; Determine the file type and return it as a string.

iunit = rsl_open_radar_file(infile, error=error)
if error then return, 'file_error'

; Read in the magic bytes used to identify the radar data format.
; (Term "magic bytes" is from the original RSL.)

magic = bytarr(11)
readu, iunit, magic

; Test for filetype.

filetype = 'unknown'
if stregex(string(magic[0:7]),'AR2V00',/boolean) || string(magic[0:7]) eq $
    'ARCHIVE2' then filetype = 'wsr88d_file' $
else if string(magic[4:5]) eq 'UF' or string(magic[0:1]) eq 'UF' or $
    string(magic[2:3]) eq 'UF' then filetype = 'uf_file' $
else if (magic[0] eq 0 and (magic[1] eq 27 or magic[1] eq 7)) or $
        (magic[1] eq 0 and (magic[0] eq 27 or magic[0] eq 7)) $
     then filetype = 'nsig_file' $
else if string(magic[1:3]) eq 'HDF' || string(magic[0:2]) eq 'CDF' then $
        filetype = get_portable_format_filetype(iunit) $
else if magic[0] eq '0e'x and magic[1] eq '03'x and magic[2] eq '13'x and $
    magic[3] eq '01'x then filetype = 'hdf_file' $
else if string(magic[4:10]) eq 'SUNRISE' then filetype = 'lassen_file'

free_lun, iunit
return, filetype
end

;******************************;
;    rsl_anyformat_to_radar    ;
;******************************;

function rsl_anyformat_to_radar, filename, siteid_or_header, $
    vos_number=vosnum, catch_error=catch_error, keep_radar=keep_radar, $
    quiet=quiet, error=error, _EXTRA=keywords

; This function determines the format of the input file and calls the
; appropriate function to read data into the radar structure.

no_radar = -1
radar = no_radar
error = 0

; Set up error handler to be used with keyword CATCH_ERROR. If CATCH_ERROR
; is 0, the error handler is canceled.

if n_elements(catch_error) eq 0 then catch_error = 1
if n_elements(keep_radar) eq 0 then keep_radar = 0

catch, errcode ; Error handler begins here.
if errcode ne 0 then begin
    catch, /cancel
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    ;message,'Error occurred while processing file '+filename+'.',/informational
    error = 1
    if not keep_radar then radar = no_radar
    return, radar
endif
if not catch_error then catch, /cancel ; Cancel error handler.

; Determine file format and call appropriate ingest function.
; ("filename[0]" is used to pass filename by value.)

case rsl_filetype(filename[0]) of
    'wsr88d_file': radar = rsl_wsr88d_to_radar(filename, siteid_or_header, $
		       catch_error=catch_error, keep_radar=keep_radar, $
                       error=error, quiet=quiet, _EXTRA=keywords)
    'uf_file':     radar = rsl_uf_to_radar(filename, error=error, quiet=quiet, $
                       catch_error=catch_error, keep_radar=keep_radar, $
                       _EXTRA=keywords)
    'nsig_file':   radar = rsl_nsig_to_radar(filename, error=error, $
	               quiet=quiet, catch_error=catch_error, $
		       keep_radar=keep_radar, _EXTRA=keywords)
    'cfradial_file': radar = rsl_cfradial_to_radar(filename, error=error, $
	               quiet=quiet, catch_error=catch_error, $
		       keep_radar=keep_radar, _EXTRA=keywords)
    'd3r_file':    radar = rsl_d3r_to_radar(filename, error=error, $
                       catch_error=catch_error, keep_radar=keep_radar, $
                       _EXTRA=keywords)
    'hdf_file':    radar = rsl_hdf_to_radar(filename, vos_number=vosnum, $
                       error=error, quiet=quiet)
    'lassen_file': radar = rsl_lassen_to_radar(filename, error=error, $
	               quiet=quiet)
    'unknown':     message,'Unrecognized format',/informational
    'file_error':  error = 1
endcase

if size(radar,/n_dimensions) eq 0 then error = 1
if error and not keep_radar then radar = no_radar
return, radar
end
