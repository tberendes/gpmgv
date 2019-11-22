; 
;        Include file HM_ERROR.inc for converted Fortran routines.
;
;        PURPOSE
;           This header include file contains the numerical error codes to 
;           be used by HM applications, utilities, and components.  Each error
;           code is represented by a literal.  Errors are grouped numerically
;           into blocks which are primarily distinguished by error type, but are
;           also grouped into application specific blocks.  A successful return
;           will always be returned as zero.
;
;           GENERAL HM error codes are found between 1000-4999. 
;           Application-specific error codes are found from 5000 and above.
;
;        NOTE: In all source code, the literal must be used.  No hard coded
;              numbering will be allowed.  This is to allow for better 
;              maintenance in the long term.
;
;***********************************************************************

;        HM shall be placed prior to all general error literals symbolic names
;
;        SUCCESS return will be 0.

      HM_SUCCESS =                          0
      HM_FAILURE =                          1
      HM_BUG =                              2
;
;        GENERAL HM error codes block: 1000-4999 begins here. 
;
;        ERRORS 1000-1999

;        MEMORY ALLOCATION ERRORS                ERROR NUMS 2000-2049

      HM_BEGIN_MEM_ALLOC_BLOCK =              2000
      HM_MEMORY_ALLOCATION_ERROR1 =           2001 ;severity levels 1-3
      HM_MEMORY_ALLOCATION_ERROR2 =           2002
      HM_MEMORY_ALLOCATION_ERROR3 =           2003
      HM_MEMORY_ALREADY_ALLOCATED_FORTRAN =   2004
      HM_MEMORY_ALLOCATION_ERROR_FORTRAN =    2005
      HM_UNEXPECTED_MEMORY_ALLOCATION_ERROR = 2006
      HM_END_MEM_ALLOC_BLOCK =                2049
;
;        OVERFLOW/UNDERFLOW ERRORS               ERROR NUMS 2050-2099
;
      HM_BEGIN_OVER_UNDER_FLOW_BLOCK =      2050
      HM_ARRAY_OVERFLOW_ERROR =             2051
      HM_ARRAY_UNDERFLOW_ERROR =            2052
      HM_OVERFLOW_ERROR =                   2053
      HM_UNDERFLOW_ERROR =                  2054
      HM_END_OVER_UNDER_FLOW_BLOCK =        2099
;
;        MATH ERRORS                             ERROR NUMS 2100-2199
;
      HM_BEGIN_MATH_BLOCK =                 2100
      HM_DIVIDE_BY_ZERO_ERROR =             2101
      HM_ZERO_IN_DENOM_FIXED =              2102
      HM_BAD_VALUE_ACOS =                   2103
      HM_INVALID_SOLUTION =                 2104
      HM_END_MATH_BLOCK =                   2199
;
;        INPUT/OUTPUT ERRORS                     ERROR NUMS 2200-2299
;
      HM_BEGIN_IO_BLOCK =                   2200
      HM_FILE_OPEN_ERROR =                  2201
      HM_FILE_CLOSE_ERROR =                 2202
      HM_GET_DATA_ERROR =                   2203
      HM_GET_SETUP_ERROR =                  2204
      HM_GET_GRID_ERROR =                   2205
      HM_GET_STATION_DATA_ERROR =           2206
      HM_GET_ENCODED_REPORT_ERROR =         2207
      HM_GET_DATA_ID_ERROR =                2208
      HM_PUT_DATA_ERROR =                   2209
      HM_PUT_SETUP_ERROR =                  2210
      HM_PUT_GRID_ERROR =                   2211
      HM_PUT_STATION_DATA_ERROR =           2212
      HM_PUT_ENCODED_REPORT_ERROR =         2213
      HM_PUT_DATA_ID_ERROR =                2214
      HM_FILE_ERROR =                       2215
      HM_IO_ERROR =                         2216
      HM_END_IO_BLOCK =                     2299



;       -MAP UTILITY ERRORS-      ERROR NUMS 2300-2349

      HM_BEGIN_MAP_BLOCK =                   2300
      HM_UNKNOWN_MAP_PROJECTION =            2301
      HM_DISTANCE_IS_ZERO =                  2302
      HMC_KM_PER_PIXEL_ERROR =               2303
      HM_END_MAP_BLOCK =                     2349

;       -TEXT WINDOW ERRORS     ERROR NUMS 2400-2499

      HM_BEGIN_TWN_BLOCK =                   2400
      HMC_TWN_INVALID_WIDGET =               2401
      HMC_TWN_NO_TEXT =                      2402
      HM_END_TWN_BLOCK =                     2499

;        APPLICATION error codes: 5000+ begins here.
;
;        CONTOUR ERROR CODES                     ERROR NUMS 5000-5099

      CTN_BEGIN_CONTOUR_BLOCK =              5000
      CTN_NO_LABELS_TO_FORMAT =              5001
      CTN_LINE_SMOOTHING_ERROR =             5002
      CTN_LINE_REPLACEMENT_ERROR =           5003
      CTN_INVALID_DIGIT_FLAG =               5004
      CTN_LINE_GEN_ERROR =                   5005
      CTN_STRUCT_INIT_ERROR =                5006
      CTN_SHADED_AREA_GEN_ERROR =            5007
      CTN_BUILD_LIST_ERROR =                 5008
      CTN_MATCH_CONTOURS_ERROR =             5009
      CTN_LINE_ANALYSIS_ERROR =              5010
      CTN_POINT_SEARCH_ERROR =               5011
      CTN_I_J_TO_LAT_LON_ERROR =             5012
      CTN_DATA_RANGE_ERROR =                 5013
      CTN_NO_CONTOUR_LEVELS =                5014
      CTN_BIT_FLAGGING_ERROR =               5015
      CTN_LABEL_GEN_ERROR =                  5016
      CTN_LINE_CONNECTION_ERROR =            5017
      CTN_END_CONTOUR_BLOCK =                5099

;        GRIB DECODER ERRORS                     ERROR NUMS 5100-5199 

      GRB_MSG_BGN_NOT_FOUND =                5100
      GRB_EDITION_NUM_ERROR =                5101
      GRB_NO_GDS_ERROR =                     5102
      GRB_MAP_PROJ_ERROR =                   5103
      GRB_SEC2TANLAT_ERROR =                 5104
      GRB_NUM_BITMAP_ERROR =                 5110
      GRB_SPECTRAL_HARM_ERROR =              5111
      GRB_BIN_SF_ERROR =                     5112
      GRB_MATRIX_VALS_ERROR =                5113
      GRB_MSG_END_NOT_FOUND =                5114
      GRB_REORDER_ERROR =                    5120
      GRB_UNPK_POS_ERROR =                   5121
      GRB_UNPK_NUMBITS_ERROR =               5122
      GRB_NULL_MSG =                         5123
      GRB_DEGRIB_DATA_ERROR =                5124
      GRB_UNPK_SMPLE_ERROR =                 5125
      GRB_UNPK_CMPLX_ERROR =                 5126
      GRB_DEGRIB_HEADER_ERROR =              5127
      GRB_FORMAT_CONVERSION_ERROR =          5128
      GRB_LOAD_OBJECT_ERROR =                5129
      GRB_UNPK_LOC_ERROR =                   5130
      GRB_GET_DATA_ERROR =                   5131
      GRB_TOO_MANY_CONVERSION_TABLES =       5132
      GRB_TIME_CONVERSION_ERROR =            5133
      GRB_BAD_TIME_RANGE_INDICATOR =         5134
      GRB_BAD_MINUTE_VALUE =                 5135
      GRB_BAD_DAY_VALUE =                    5136
      GRB_BAD_MONTH_VALUE =                  5137
      GRB_BAD_HOUR_VALUE =                   5138
      GRB_BAD_TIME_UNIT =                    5139
      GRB_BAD_SECOND_VALUE =                 5140

;        NEXRAD IMAGE DISPLAY ERRORS             ERROR NUMS 5200-5299 

      NXL_BEGIN_NEXRAD_BLOCK =                5200
      NXL_UNKNOWN_MODE =                      5201
      NXL_UNKNOWN_SITE =                      5202
      NXL_UNKNOWN_PRODUCT =                   5203
      NXL_UNKNOWN_BLOCK_ID =                  5204
      NXL_BLOCK_PROCESS_ERROR =               5205
      NXL_MAP_TRANSFORM_ERROR =               5206
      NXL_CANNOT_FLAG_SUBGRID =               5207
      NXL_BAD_AZLINE_SPACING =                5208
      NXL_RING_DATA_MISSING =                 5209
      NXL_AZLINE_DATA_MISSING =               5210
      NXL_BLOCK_MISSING =                     5211
      NXL_CANNOT_PROCESS_PACKET =             5212
      NXL_INCORRECT_PACKET =                  5213
      NXL_PACKET_DATA_MISSING =               5214
      NXL_NO_NEXRAD_MESSAGE =                 5215
      NXL_END_NEXRAD_BLOCK =                  5299

;       -EQUATION INTERPRETER ERRORS-     ERROR NUMS 5300-5399

      ITR_BEGIN_INTERPRETER_BLOCK =           5300
      ITR_SYNTAX_ERROR =                      5301
      ITR_SEMANTIC_ERROR =                    5302
      ITR_ARGUMENT_ERROR =                    5303
      ITR_DATA_ERROR =                        5304
      ITR_RANGE_ERROR =                       5305
      ITR_DM_BOMBED =                         5306
      ITR_END_INTERPRETER_BLOCK =             5399

;       -DERIVED PARAMETER ERRORS-        ERROR NUMS 5400-5499

      DVP_BEGIN_PARAMETER_BLOCK =             5400
      DVP_UNKNOWN_DERIVED_PARAMETER =         5401
      DVP_MAP_PROJ_NOT_AVAILABLE =            5402
      DVP_LL_LONG_NOT_IN_RANGE =              5403
      DVP_ORIENT_LONG_NOT_IN_RANGE =          5404
      DVP_LL_LAT_NOT_IN_RANGE =               5405
      DVP_LONG_NOT_EAST_OR_WEST =             5406
      DVP_STND_PARALLEL_CLOSE_TO_EQUATOR =    5407
      DVP_STND_PARALLEL_NOT_IN_RANGE =        5408
      DVP_MESH_LENGTH_ZERO =                  5409
      DVP_END_PARAMETER_BLOCK =               5499
      
;        - GRID TRANSFORMATIONS-

      GCT_I_J_TO_LAT_LON_ERROR =                   6000
      GCT_MAP_PROJ_NOT_AVAILABLE =                 6001
      GCT_LL_LONG_NOT_IN_RANGE =                   6002
      GCT_ORIENT_LONG_NOT_IN_RANGE =               6003
      GCT_LL_LAT_NOT_IN_RANGE =                    6004
      GCT_STND_PARALLEL_NOT_IN_RANGE =             6005
      GCT_LONG_NOT_EAST_OR_WEST =                  6006
      GCT_MESH_LENGTH_ZERO =                       6007
      GCT_STND_PARALLEL_CLOSE_TO_EQUATOR =         6008
      GCT_ARRAY_SIZES_INCORRECT =                  6009
      

