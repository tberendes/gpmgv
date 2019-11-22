
; This file contains procedures and functions for reading data
; from HDF5 files. 
; J.K. 7/05
; updated 9/11 IDL must have ability to read HDF5 1.8 files
;
; h5objlist  pro: gets list of objects below a node in HDF5 file
; h5listall  pro: driver for h5objlist to return all objects in a file
; h5read_ds  pro: display selectable listbox of datasets and return
;                  one dataset
;                  depends on xlist.pro (esrg repo). 
; h5ds_read func: function to return one named dataset from file.
; h5printlist pro:print out list of objects in HDF5 file.

pro h5objlist, id, id_name,number,objname,objloc,type,first=first
  
   ; Get a list of all the datasets/groups in an HDF5 file
   ; starting with the level associated with id.
   ; File must be opened previously with H5F_OPEN()
   ; 
   ; This procedure can be called recursively.
   ; Top level group is assumed to be '/'.
   ; 
   ; J.K. 7/05.

   ; A common block is used to hold previous information between calls.
   ; BAD PROGRAMMING DISCLAIMER APPLIES!!!

   ; How do we know this is the first call to this 
   ; procedure? The first call sets the 'first' keyword. All
   ; other recursive calls omit the keyword. 

   ; *** It is assumed that the first user call 
   ; (with first keyword set) will have the top level group of '/'. 

   ; INPUTS
   ; id      HDF5 file or group id 
   ; id_name HDF5 group name string

   ; OUTPUTS
   ; number  accumulated number of objects under id
   ; objname string array of object names
   ; objloc  string array of full object path/name
   ; type    array of structures of object types
   ;         type string is at type().type 
  

   ; This common block holds info that needs to be saved
   ; between recursive calls.
   common h5com, grouplevel,prefix
   
   ; Top level directory in HDF5 file is '/'.
   TOP = '/'
   ; Maximum number of data sets at this level.
   MAXNUM = 1024

   ; Set up variables if this is called by a user (first time).
   if (keyword_set(first) ) then begin
    grouplevel = 0; 
   ; this holds the absolute number of elements 
    number = 0
    prefix = TOP
    objloc = strarr(MAXNUM)
    objname = strarr(MAXNUM)
   ; initialize the type structure
   ; get the object info of the current id
   top_id = h5g_open(id,id_name)
   type = h5g_get_objinfo(top_id,id_name)
   type = replicate(type,MAXNUM)    
   endif
    
   ; Get number of groups at this level.
   ; numsets is number of elements under current group
   numsets = h5g_get_nmembers(id,id_name)

;   print,'numsets, grouplevel, prefix:', numsets, grouplevel, prefix 

   ; add the number of members to the total
   ; but save the old total first
   tnumber = number
   number = number + numsets
 LF=STRING(10b)  ; Morris addition, add a newline at the end of each loc
   ; Loop over each member
   for i = 0, numsets-1 do begin
   ; Increment the absolute number of this member
      tnumber = tnumber + 1  
    
   ; Get member name 
      objname(tnumber) = h5g_get_member_name(id,id_name,i)
      objloc(tnumber) = prefix + objname(tnumber) ;+ LF
      type(tnumber) = h5g_get_objinfo(id,objname(tnumber))

      print, objloc(tnumber)

   ; Check to see if member is a 'GROUP'
      if (type(tnumber).type eq 'GROUP') then begin
           grouplevel = grouplevel+1
 ;          print, 'grouplevel', grouplevel
   
   ; We want to add "/name" everytime we move down
   ; into another sub level. This does not work when we're
   ; at the top level, we only want to add "name". 
           if (grouplevel eq 1) then begin
            prefix = prefix + objname(tnumber) 
           endif else begin
             prefix = prefix + objname(tnumber)
           endelse
           prefix = prefix + TOP

 ;          print, 'prefix for next call' , prefix
   ; Open the current group
           id2 = h5g_open(id,prefix)
   
   ; Make another call to this routine to get the 
   ; objects in this group.
           h5objlist, id2,prefix, number, objname,objloc, type
           h5g_close, id2
   ; After we come back take one away from grouplevel
           grouplevel = grouplevel -1
  
 ;          print, 'back from a group grouplevel', grouplevel

   ; Pop off the last directory from prefix.
           parts = str_sep(prefix,'/')
 ;          print, 'parts:', parts
           sz = n_elements(parts)
           newprefix = TOP
           if (grouplevel gt 0) then begin
             for j = 0,grouplevel do begin
               newprefix = newprefix + parts(j)
             endfor
             prefix = newprefix + TOP
           endif
           if (grouplevel eq 0) then prefix = '/'
;           print, 'new prefix', prefix

       endif ;end of group if
   endfor ;end of member loop

end
      
      
pro h5listall, file,number,list,loc,type
   
   ; Get a list of all the datasets/groups in an HDF5 file
   ; starting with the top level.
   ; Top level group is assumed to be '/'.
   ; J.K. 7/05

   ; INPUT
   ; file  filename string

   ; OUTPUT
   ; number total number of objects in file
   ; list   string array of object names
   ; loc    string array of full object path/name 
   ; type   array of structures of object types

   ; Maximum number of data sets at this level.
   MAXNUM = 1024

   TOP = '/'

   ; Number of data sets
   num = 0

   if (not H5F_IS_HDF5(file)) then $
       MESSAGE, '"'+file+'" is not a valid HDF5 file.'
  
   ; Open file
   file_id = h5f_open(file) 

   ; Call procedure to list all under this level
   ; Since this is a user call must set 'first' keyword
   h5objlist, file_id, TOP, number,list,loc,type,first=1
   h5f_close, file_id

;   print, number
;   for i = 0,number-1 do begin
;     print, list(i),' ', type(i).type,' ', loc(i)
;   endfor
end

pro h5read_ds, file, name

 ; INPUT 
 ; file      filename string
 ; name      name of variable to hold selected object
 ; 
 ; Usage h5read_ds ,file,name
 
 ; This routine will put up a list of all the 
 ; datasets in the file. The selected dataset
 ; will be put in the variable 'name'.
 ; 
 ; 'name'  will be the appropriate IDL type for the DATASET
 ; Note that the result may be a structure if the DATASET is compound!
 ; J.K. 7/05 

 ; open file
 file_id = h5f_open(file)
 
 if(file_id le 0) then begin
   print, 'Error: File is not a valid HDF5 file'
 endif

 ; get list of all objects in the file starting at '/'.
 h5objlist, file_id,'/',number,names,loc,type,first=1

 ; display a list box of the dataset names
 isds = where(type(*).type eq 'DATASET')
; ds_name = xlist(loc(isds),title='Select a dataset')
ds_name=' ' 
 ; find named object in list
 index = where(loc eq ds_name)
 if(index lt 0) then begin
   print, 'Error: ',name, ' not in file ',file
 endif
   
 ; use HDF5 routines to open dataset and read in data
 data_id = h5d_open(file_id,loc(index))
 name = h5d_read(data_id)
 h5d_close, data_id
  
 end  
   
 function h5ds_read, file, name

 ; INPUT 
 ; filename  string
 ; name      name of object
 ; 
 ; Usage result = h5ds_read(file,'name')
 ; result = -1 on error
 ; 
 ; name should be the name of a DATASET, not a GROUP
 ; result will be the appropriate IDL type for the DATASET
 ; Note that the result may be a structure if the DATASET is compound!
 ; J.K. 7/05 

 ; open file
 file_id = h5f_open(file)
 
 if(file_id le 0) then begin
   print, 'Error: File is not a valid HDF5 file'
   return, -1
 endif

 ; get list of all objects in the file starting at '/'.
 h5objlist, file_id,'/',number,names,loc,type,first=1

 ; find named object in list
 index = where(loc eq name)

 if(index lt 0) then begin
   print, 'Error: ',name, ' not in file ',file
   return, -1
 endif

 sz_index = '   
 ; check to make sure this is a DATASET
 if (type(index).type ne 'DATASET') then begin
   print, 'Error: ',name, ' is not a DATASET'
   return, -1
 endif

 ; use HDF5 routines to open dataset and read in data
 data_id = h5d_open(file_id,loc(index))
 result = h5d_read(data_id)
 h5d_close, data_id
 return, result 
  
 end
 
pro  h5printlist, file

  h5listall, file,number,list,loc,type
  print, 'File: ',file
  for i = 1, number-1 do print, strtrim(loc(i),2), '   '+type(i).type, format='(A-40,A20)'
  end

