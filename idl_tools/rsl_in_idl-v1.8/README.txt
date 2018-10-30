RSL_in_IDL

Requirements
------------

To use RSL_in_IDL you must have access to IDL, the Interactive Data Language.
IDL is available from Exelis Visual Information Solutions (www.excelisvis.com).


Systems
-------

RSL_in_IDL works on Linux and Mac operating systems.


Installing RSL_in_IDL
-------------------------------

Untar the package:

  tar xf rsl_in_idl-v1.8.tar

cd to the package directory and run the script 'rslinstall':

  cd rsl_in_idl-v1.8
  rslinstall

The default target directory is $HOME/idl/rsl_in_idl/.  You can specify a
different directory by giving its full path name as an argument to
rslinstall.  For example:

  rslinstall $HOME/myrsl

This will install the program files into $HOME/myrsl/rsl_in_idl/.

If the target directory already exits, rslinstall will prompt you for
permission to overwrite it.  You can prevent the prompt by using the '-f'
option.  This will cause the default directory to be overwritten:

  rslinstall -f 


Add RSL_in_IDL to the IDL Search Path
-------------------------------------

To complete installation, add the rsl_in_idl directory to IDL's search path.

One way to do this is to set the IDL_PATH preference within IDL:

  pref_set, 'IDL_PATH', '<IDL_DEFAULT>:/home/youruserid/idl/rsl_in_idl', /commit

You only need to do this once; IDL Preferences are retained between sessions.

Another way is to set the environment variable IDL_PATH.  You would normally do
this in your shell startup file (.bashrc, .tcshrc, etc.) using one of the
following commands, depending on your shell:

# bash or ksh:
  export IDL_PATH='<IDL_DEFAULT>:/home/userid/idl/rsl_in_idl'

# tcsh or csh:
  setenv IDL_PATH '<IDL_DEFAULT>:/home/userid/idl/rsl_in_idl'

All of the above methods cause the !PATH system variable to be set in IDL.
IDL uses !PATH to find program files.  '<IDL_DEFAULT>' is a symbolic name for
the IDL distribution directories, and should always be included.  The path
setting in the above examples tells IDL to search first in the standard IDL
directories, then in userid's rsl_in_idl directory.


Makefile Error Message 
----------------------

If you don't use WSR-88D data, you can skip this part.

WSR-88D Level 2 data archived from June 1, 2016, onward, uses internal bzip2
compression.  The first time you read one of these files, you might see a
message similar to the following:

    OPEN_WSR88D_FILE: decoder executable does not exist.
    Will attempt to make decoder in ~/idl/rsl_in_idl/decode_ar2v/:
    gcc -o decode_ar2v -I ./ decode_ar2v.c -lbz2
    . . .
    /usr/bin/ld: cannot find -lbz2
    collect2: error: ld returned 1 exit status
    Makefile:2: recipe for target 'decode_ar2v' failed
    make: *** [decode_ar2v] Error 1

The likely cause of the error is that the bzip2 library is not installed on
your machine.

Install the bzip2 library and try again.  Their home page is at
http://www.bzip.org.

The Makefile and the decoder program (decode_ar2v.c) which uses the bzip2
library are both located in rsl_in_idl/decode_ar2v/.
For more information on the change in archiving procedures, see
http://www.nws.noaa.gov/os/notification/tin16-12nexrad_format_change.htm


Please send questions or comments about RSL-in-IDL to
gsfc-rsl-help@lists.nasa.gov.
