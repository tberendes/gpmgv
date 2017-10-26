;******************************;
;     lassen_angle_convert     ;
;******************************;

function lassen_angle_convert, coded_angle
angle = ishft((ulong(coded_angle)+22L)*360L, -14)
return, uint(angle)
end

;******************************;
;     read_lassen_rayhdr       ;
;******************************;

pro read_lassen_rayhdr, unit, lassen_rayhdr

NUMOFFSETS = 10

lassen_rayhdr = { $
  vangle:0U,  $ ;   /* Azimuth angle.       */
  fanglet:0U, $ ;   /* Target fixed angle.  */
  fanglea:0U, $ ;   /* Actual fixed angle.  */
  a_start:0U, $ ;   /* Azimuth angle start.  */
  a_stop:0U, $ ;    /* Azimuth angle stop.  */
  max_height:0U, $; /* Maximum height, km.  */
  volume:0U, $ ;    /* Volume serial number. */
  sweep:0U, $ ;     /* Sweep number 1..LASSEN_MAX_SWEEPS */
  sweep_type:0U, $; /* Sweep type.              */
  gatewid:0U, $ ;   /* Gate width, meters.  */
  rangeg1:0U, $ ;   /* Range to gate 1, meters. */
  numgates:0U, $ ;  /* Number of gates.         */
  prf:0U, $ ;       /* Primary prf, hz.      */
  prflow:0U, $ ;    /* Secondary prf, hz.  */
  n_pulses:0U, $ ;  /* Sample size in pulses. */
  p_width:0U, $ ;   /* Pulse width, .05 us units.*/
  cfilter:0U, $ ;   /* Clutter filter code.   */
  status:0U, $ ;    /* Hardware status word. */
  flags:0U, $
  offset:uintarr(NUMOFFSETS), $
  year:0U, $ ;   /* year-1900   */
  month:0U, $ ;  /* month  1-12 */
  day:0U, $ ;    /* day    1-31 */
  hour:0U, $ ;   /* hour   0-23 */
  minute:0U, $ ; /* minute 0-59 */
  second:0U  $ ; /* second 0-59 */
}

readu, unit, lassen_rayhdr
end

;******************************;
;      read_lassen_hdr         ;
;******************************;

pro read_lassen_hdr, unit, lassen_hdr

; Read Lassen header.

lasstime = {lassen_time, $
  year:0L,   $ ; /* year - 1900 */
  month:0L,  $ ; /* 1-12  */
  day:0L,    $ ; /* 1-31  */
  hour:0L,   $ ; /* 0-23  */
  minute:0L, $ ; /* 0-59  */
  second:0L  $ ; /* 0-59  */
}

; Note on strings in XDR: XDR maintains string lengths in the data, so we
; don't have to know the exact length when we allocate the byte array that
; receives the string.  Of course it should be at least as long as the string,
; but if it isn't, the string is simply truncated.

lassen_hdr = { $
  magic:bytarr(8),        $ ; /* Magic number.  This must be 'SUNRISE'. */
  mdate:{Lassen_time},    $ ; /* Last modification. */
  cdate:{Lassen_time},    $ ; /* Creation date.     */
  type:0L,                $ ; /* Field type.        */
  mwho:bytarr(16),        $ ; /* Last person to modify.   */
  cwho:bytarr(16),        $ ; /* Person who created file. */
  protection:0L,          $ ; /* Is file protected? */
  checksum:0L,            $ ; /* Data bcc.   */
  description:bytarr(40), $ ; /* File description. */
  id:0L, $
  spare:lonarr(12) $
}

readu, unit, lassen_hdr
end

;******************************;
;     read_lassen_volhdr       ;
;******************************;

pro read_lassen_volhdr, unit, volhdr

; Read volume

LASSEN_MAX_SWEEPS = 30
NUMOFFSETS = 10

; Version must be either 13 or 14 (for 1.3, 1.4).
volhdr = {  $  ;  Lassen_volume
  version:0, $ ; /* Raw version number.  */
  filled:0, $  ;  /* <0=empty 0=filling >0=full. */
  volume:0U, $ ;     /* Volume serial number.  */
  sweep:0U, $ ;      /* Sweep index 1 -> max. */
  sweep_type:0U, $ ; /* Sweep type code.   */
  max_height:0U, $ ; /* Maximum height, km.  */
  status:0U, $ ;     /* Status word. */
  min_fangle:0U, $ ; /* Minimum fixed angle.  */
  max_fangle:0U, $ ; /* Maximum fixed angle.  */
  min_var:0U, $ ;    /* Minimum variable angle. */
  max_var:0U, $ ;    /* Maximum variable angle. */
  a_start:0U, $ ;    /* Variable angle start. */
  a_stop:0U, $ ;     /* Variable angle stop.  */
  numsweeps:0U, $ ;  /* Number of sweeps in volume. */
  fangles:uintarr(LASSEN_MAX_SWEEPS), $ ; /* Fixed angles for each sweep. */
  
  gatewid:0U, $ ; /* Gate width, meters.  */
  rangeg1:0U, $ ; /* Range to gate 1, meters. */
  numgates:uintarr(LASSEN_MAX_SWEEPS), $ ; /* Gates for each sweep. */
  maxgates:0U, $ ; /* Max # of gates in volume. */
  unused:uintarr(4), $
  prf:0U, $ ;      /* Primary prf, hz. */
  prflow:0U, $ ;   /* Secondary prf, hz. */
  freq:0UL, $ ;  /* Mhz * 10   */
  n_pulses:0U, $ ; /* Sample size in pulses. */
  offset:uintarr(NUMOFFSETS,LASSEN_MAX_SWEEPS), $
  year:0U,    $ ; /* Year - 1900      */
  month:0U,   $ ; /* Month 1-12        */
  day:0U,     $ ; /* Day   1-31        */
  shour:0U,   $ ; /* Start hour   0-23 */
  sminute:0U, $ ; /* Start minute 0-59 */
  ssecond:0U, $ ; /* Start second 0-59 */
  ehour:0U,   $ ; /* End hour   0-23   */
  eminute:0U, $ ; /* End minute 0-59   */
  esecond:0U, $ ; /* End second 0-59   */
  volflags:0U,$ ; /* Software status flags. */
  radar_name:bytarr(8), $
  site_name:bytarr(8), $
  antenna_height:0U, $
  latdeg:0, $
  latmin:0, $
  latsec:0, $
  londeg:0, $
  lonmin:0, $
  lonsec:0  $
}

readu, unit, volhdr
end

;******************************;
;      new_lassen_sweep        ;
;******************************;

function new_lassen_sweep

sweep = ptr_new( $
{ $
  hdr: { $
    sweepnum:0U, $ ;  /* Sweep number. */
    fangle:0U,   $ ;  /* Fixed, azimuth angle.  */
    numrays:0U   $ ;  /* Number of rays this sweep. */
  }, $
  ray:ptrarr(360) $ ; /* The Lassen_ray pointers. */
})

return, sweep
end

;******************************;
;     rsl_read_lassen_file     ;
;******************************;

pro rsl_read_lassen_file, infile, vol, error

; Note: Lassen data is written in XDR (External Data Representation).  Here
; the 'xdr' keyword is passed to 'openr' in rsl_open_radar_file.  IDL knows
; how to convert XDR; no additional routines are required as in C.

unit = rsl_open_radar_file(infile, /xdr, error=error)
if error then goto, finished

isweep = -99
iray = 0
LASSEN_MAX_SWEEPS = 30

read_lassen_hdr, unit, lassen_hdr
read_lassen_volhdr, unit, volhdr

vol = { $
  hdr:volhdr, $
  sweep:ptrarr(LASSEN_MAX_SWEEPS) $ ; /* The Lassen_sweep pointers. */
}

error = 0
version = volhdr.version
if version ne 13 and version ne 14 then begin
    message,string(format='("Incompatable version number: ' + $
        'Coded version =",i3," = Version",f4.1)',version,version/10.), $
	/continue
    error = 1
    goto, finished
endif

volser = volhdr.volume and '00ff'x
while not eof(unit) do begin
    read_lassen_rayhdr, unit, rayhdr
    azimuth = lassen_angle_convert(rayhdr.vangle)
    if azimuth  lt 0 or azimuth gt 360 then begin
	message,'Azimuth angle out of range:' + string(azimuth), /continue
	error = 1
	goto, finished
    endif
    if rayhdr.volume ne volser then begin
	message,string(format='("Volume serial number out of sync:",/' + $
                '"         rayhdr.volume = ",i," Should be ",i)', $
		  rayhdr.volume, volser),/continue
	if isweep eq -99 then error = 1
	goto, finished
    endif

    ; if new sweep then do sweep allocation and variable resets.

    if rayhdr.sweep-1 ne isweep then begin
	 if isweep gt -1 then begin
	     (*sweep).hdr.numrays = iray
	     vol.sweep[isweep] = sweep
	 endif
	 isweep = fix(rayhdr.sweep)-1;
         sweep = new_lassen_sweep()
	 (*sweep).hdr.fangle = rayhdr.fanglet
	 (*sweep).hdr.sweepnum = rayhdr.sweep
	 iray = 0
    endif
    raysize = n_elements(where(rayhdr.offset)) * rayhdr.numgates
;   (note: In IDL, byte data type is unsigned, so no need to cast the data.)
    raydata = bytarr(raysize)
    readu, unit, raydata

    ; combine rayhdr and raydat, store into sweep

    ray = ptr_new({hdr:rayhdr,data:bytarr(raysize)})
    (*ray).data = raydata
    (*sweep).ray[iray] = ray
    iray = iray + 1
endwhile

; assign last sweep to vol.

(*sweep).hdr.numrays = iray
vol.sweep[isweep] = sweep
if vol.hdr.numsweeps ne isweep+1 then begin
    message, 'Warning: number of sweeps read (' + strtrim(isweep+1,1) + $
        ') is different from number expected (' + $
	strtrim(vol.hdr.numsweeps,1) + ').', /continue
    vol.hdr.numsweeps = isweep+1
endif

finished:
if unit gt 0 then free_lun, unit
end
