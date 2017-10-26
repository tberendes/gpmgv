PRO test_read_3b42_file

filename = '/data/gpmgv/GPMtest/zipfiles/fileL3B42.hdf'
IF FILE_TEST(filename) EQ 0 THEN BEGIN
   filename = DIALOG_PICKFILE(PATH='~', TITLE='Select a 3B42 file', FILTER='*3B42*')
END

FileHeader=''
GridHeader=''
NLON=0
NLAT=0
precipitation=0.0
relativeError=0.0
satPrecipitationSource=0.0
HQprecipitation=0.0
IRprecipitation=0.0
satObservationTime=0.0
VERBOSE=1

status=read_3b42_file( filename, gridheaderStruc=gridheader, $
fileheaderStruc=fileheader, precipitation=precipitation, $
relativeError=relativeError, satPrecipitationSource=satPrecipitationSource, $
HQprecipitation=HQprecipitation, IRprecipitation=IRprecipitation, $
satObservationTime=satObservationTime, nlon=nlon, nlat=nlat, VERBOSE=VERBOSE )

help, gridheader, /structure
help, fileheader, /structure
help, nlon, nlat, precipitation, relativeError, satPrecipitationSource, $
      HQprecipitation, IRprecipitation, satObservationTime

end
