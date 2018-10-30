function rsl_new_ray, nbins

; Return a ray structure.
;
; Syntax:
;     ray = rsl_new_ray(nbins)
;
; Inputs:
;     nbins:   The maximum number of bins or cells in a ray.
; 

compile_opt hidden

rayhdr = {month:0, day:0, year:0, hour:0, minute:0, sec:0.0, unam_rng:0.0, $
    azimuth:-99999.0, ray_num:0, elev:0.0, elev_num:0, range_bin1:0, $
    gate_size:0.0, vel_res:0.0, sweep_rate:0.0, prf:0, azim_rate:0.0,  $
    fix_angle:0.0, pitch:0.0, roll:0.0, heading:0.0, pitch_rate:0.0, $
    roll_rate:0.0, heading_rate:0.0, lat:0.0, lon:0.0, alt:0, rvc:0.0, $
    vel_east:0.0, vel_north:0.0, vel_up:0.0, pulse_count:0, pulse_width:0.0, $
    beam_width:0.0, frequency:0.0, wavelength:0.0, nyq_vel:0.0, nbins:0}

return, {h:rayhdr,range:fltarr(nbins)}
end
