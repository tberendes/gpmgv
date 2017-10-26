RSL in IDL

Requirements
------------

To use RSL in IDL you must have access to IDL, the Interactive Data Language.
IDL is available from Exelis Visual Information Solutions (www.excelisvis.com).


Systems
-------

RSL in IDL works on Linux and Mac operating systems.


Installing RSL in IDL
-------------------------------

Untar the package:

  tar xf rsl_in_idl-v1.6.tar

cd to the package directory and run the script 'rslinstall':

  cd rsl_in_idl-v1.6
  rslinstall

The default target directory is $HOME/idl/rsl_in_idl/.  You can specify a
different target directory by giving its full path name as an argument to
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

  pref_set, 'IDL_PATH', '<IDL_DEFAULT>:/home/userid/idl/rsl_in_idl', /commit

You only need to do this once; IDL Preferences are retained between sessions.

An alternative way to set IDL_PATH is through the environment variable of the
same name.  You would normally do this in your shell initialization file
(.bashrc, .tcshrc, etc.) using one of the following commands, depending on
your shell:

# bash or ksh:
  export IDL_PATH='<IDL_DEFAULT>:/home/userid/idl/rsl_in_idl'

# tcsh or csh:
  setenv IDL_PATH '<IDL_DEFAULT>:/home/userid/idl/rsl_in_idl'

All of the above methods cause the !PATH system variable to be set in IDL.
IDL uses !PATH to find program files.  '<IDL_DEFAULT>' is a symbolic name for
the IDL distribution directories, and should always be included.  The path
setting in the above examples tells IDL to search first in the standard IDL
directories, then in your rsl_in_idl directory.


Send questions or comments to help@radar.gsfc.nasa.gov.
