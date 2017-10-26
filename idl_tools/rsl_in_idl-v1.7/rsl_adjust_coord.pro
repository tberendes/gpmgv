function rsl_adjust_coord, xnorm, ynorm

; Adjust normalized coordinates for multiple plots.
;
; Inputs:
;   xnorm: x value in normalized coordinate system.
;   ynorm: y value in normalized coordinate system.
;

x = !x.region[0] + xnorm * (!x.region[1] - !x.region[0])
y = !y.region[0] + ynorm * (!y.region[1] - !y.region[0])

return, [x, y]
end
