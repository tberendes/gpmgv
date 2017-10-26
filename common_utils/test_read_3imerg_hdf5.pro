PRO test_read_3imerg_hdf5, DEBUG=debug_in

debug = KEYWORD_SET(debug_in)

filename = '/data/gpmgv/GPMtest/zipfiles/fileL3IMERGH.HDF5'
IF FILE_TEST(filename) EQ 0 THEN BEGIN
   filename = DIALOG_PICKFILE(PATH='~', TITLE='Select a 3IMERG file', FILTER='*3IMERG*')
END

struct3IMERG=read_3imerg_hdf5( filename, DEBUG=debug, /READ_ALL )

print, ''
print, 'Reading file ', filename
print, ''
print, '======================================================================='
print, ''

help, struct3IMERG.gridheader, /structure
print, ''
print, '======================================================================='
print, ''
help, struct3IMERG.fileheader, /structure
print, ''
print, '======================================================================='
print, ''
help, (*struct3IMERG.GridData), /structure

print, ''
print, '======================================================================='
print, ''

; are we dealing with a monthly or hourly file?  Grid field names differ.
accum_pos = STRPOS(filename, '3IMERG')
IF accum_pos NE -1 THEN BEGIN
   accum_type = STRMID(filename, accum_pos+STRLEN('3IMERG'),1)
   CASE accum_type OF
      'H' : BEGIN
           ; example of how to de-reference one of the grid fields from
           ; the pointer GridData
            precipitation_copy = ((*struct3IMERG.GridData).PRECIPITATIONCAL)
            END
      'M' : BEGIN
            precipitation_copy = ((*struct3IMERG.GridData).PRECIPITATION)
            END
     ELSE : message, "Error determining M or H in filename "+filename
   ENDCASE
ENDIF ELSE message, "Can't find substring '3IMERG' in file name "+filename

; print the max value of the gridfield
print, "Max. precipitation: ", max(precipitation_copy)

; do the same thing without making a copy of the PRECIPITATION(CAL) grid:
CASE accum_type OF
   'H' : print, "Max. precipitation: ", $
            max(  ((*struct3IMERG.GridData).PRECIPITATIONCAL)  )
   'M' : print, "Max. precipitation: ", $
            max(  ((*struct3IMERG.GridData).PRECIPITATION)  )
ENDCASE

; free the pointer to GridData to release the memory, 
; assuming we are done with the gridded arrays

ptr_free, struct3IMERG.GridData

end
