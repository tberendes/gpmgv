;+
; Copyright © 2014, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; get_3imerg_datasets.pro         Bob Morris, GPM GV/SAIC   January 2014
;
; DESCRIPTION
; -----------
; Given the HDF5 ID of its 3IMERG grid group, gets each gridded dataset element 
; for the group and returns a structure containing the individual grid names
; as the structure tags, and the full dataset arrays as the structure values.
; Reads either an hourly (3IMERGH) or monthly (3IMERGM) file, as specified by
; the "label" parameter.  Gridded datasets differ between the two file types.
; Returns -1 in case of errors.
;
; PARAMETERS
; ----------
; group_id  -- HDF5 ID of the grid group
; label     -- String with the AlgorithmID, either '3IMERGH' or '3IMERGM'.
; read_all  -- Binary parameter.  If set, then read and return all datasets in
;              the groups.  Otherwise, just read the datasets needed for basic
;              display and processing (subjective list).
;
; HISTORY
; -------
; 01/02/14  Morris/GPM GV/SAIC
; - Created from read_2agprofgmi_hdf5.pro.
;
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-

FUNCTION get_3imerg_datasets, group_id, label, READ_ALL=read_all

   all = KEYWORD_SET(read_all)

   nmbrs = h5g_get_num_objs(group_id)
;   print, "No. Objects = ", nmbrs
   ; identify and extract the datasets one by one
   dtnames=STRARR(nmbrs)
   for immbr = 0, nmbrs-1 do begin
      ; get the object's information
      dtnames[immbr]=H5G_GET_OBJ_NAME_BY_IDX(group_id,immbr)
      info=H5G_GET_OBJINFO(group_id, dtnames[immbr])
;      print, dtnames[immbr], ": ", info.type
      IF info.type EQ 'DATASET' THEN BEGIN
         dtID = h5d_open(group_id, dtnames[immbr])
         CASE label OF
           '3IMERGH' : BEGIN
             CASE dtnames[immbr] OF
                 'HQobservationTime1' : HQobservationTime1 = h5d_read(dtID)
                 'HQobservationTime2' : HQobservationTime2 = h5d_read(dtID)
                 'HQprecipSource1' : HQprecipSource1 = h5d_read(dtID)
                 'HQprecipSource2' : HQprecipSource2 = h5d_read(dtID)
                 'HQprecipitation' : HQprecipitation = h5d_read(dtID)
                 'IRkalmanFilterWeight' : IRkalmanFilterWeight = h5d_read(dtID)
                 'IRprecipitation' : IRprecipitation = h5d_read(dtID)
                 'precipitationCal' : precipitationCal = h5d_read(dtID)
                 'precipitationUncal' : precipitationUncal = h5d_read(dtID)
                 'randomError' : randomError = h5d_read(dtID)
                ELSE : BEGIN
                          h5d_close, dtID
                          message, "Unknown group member: "+dtnames[immbr], /INFO
                          return, -1
                       END
             ENDCASE
           END
           '3IMERGM' : BEGIN
             CASE dtnames[immbr] OF
                 'gaugeRelativeWeighting' : IF all THEN gaugeRelativeWeighting $
                                            = h5d_read(dtID)
                          'precipitation' : precipitation = h5d_read(dtID)
                            'randomError' : IF all THEN randomError = $
                                            h5d_read(dtID)
                ELSE : BEGIN
                          h5d_close, dtID
                          message, "Unknown group member: "+dtnames[immbr], /INFO
                          return, -1
                       END
             ENDCASE
           END
         ENDCASE
         h5d_close, dtID
      ENDIF
   endfor

   CASE label OF
      '3IMERGH' : BEGIN
         IF all THEN BEGIN
         datasets_struc = { source : label, $
                            HQobservationTime1 : HQobservationTime1, $
                            HQobservationTime2 : HQobservationTime2, $
                            HQprecipSource1 : HQprecipSource1, $
                            HQprecipSource2 : HQprecipSource2, $
                            HQprecipitation : HQprecipitation, $
                            IRkalmanFilterWeight : IRkalmanFilterWeight, $
                            IRprecipitation : IRprecipitation, $
                            precipitationCal : precipitationCal, $
                            precipitationUncal : precipitationUncal, $
                            randomError : randomError }
         ENDIF ELSE BEGIN
         datasets_struc = { source : label, $
                            HQprecipitation : HQprecipitation, $
                            IRprecipitation : IRprecipitation, $
                            precipitationCal : precipitationCal, $
                            precipitationUncal : precipitationUncal }
         ENDELSE
      END
      '3IMERGM' : BEGIN
         IF all THEN BEGIN
         datasets_struc = { source : label, $
                            gaugeRelativeWeighting : gaugeRelativeWeighting, $
                            precipitation : precipitation, $
                            randomError : randomError }
         ENDIF ELSE BEGIN
         datasets_struc = { source : label, $
                            precipitation : precipitation }
         ENDELSE
      END
   ENDCASE

return, datasets_struc
end
