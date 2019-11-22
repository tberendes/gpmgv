    pro run_reorder,site,year,month
;
; *** Program to exectute NCAR's reorder on a directory of compressed
; *** UF files.  
;
    in_base_dir = '/data3/trmmgv/'
    out_base_dir = '/d1/wolff/MELB_GRIDDED/'
; 
;   run_reorder,'MELB','2005','09'
;
    run_file = 'reorder_' + site + '_' + year + '_' + month + '_CZ.inp'
    print,'REORDER run file: ' + run_file

    the_date = month + '-' + year
    uf_dir = in_base_dir + site + '/1C-UF/' + year + '/' + the_date + '/' 

    out_dir  = out_base_dir + site + '/' + year + '/' + the_date + '/'
    print,'Out Dir: ' + out_dir
    spawn,'mkdir -p ' + out_dir
;
; *** Set up directories for REORDER
;
    cdf_dir = out_dir + 'CDF/' 
    print,'CDF Dir: ' + cdf_dir
    spawn,'mkdir -p ' + cdf_dir
    
    log_dir = out_dir + 'LOG/'
    print,'LOG Dir: ' + log_dir
    spawn,'mkdir -p ' + log_dir

    print,'Creating junk file...'
    spawn,'touch junk'
;
; *** Get a list of files
;
    wc = uf_dir + '*.uf.gz'
    files = file_search(wc,COUNT=nf)
    if(nf eq 0) then begin
        print,'No UF files found in ' + wc 
        stop
    endif
;
; *** Grid the files
;
    for i=0L,nf-1 do begin
        cf = files(i)
        flag = uncomp_file(cf,file)
        if(flag ne 'OK') then begin
            print,flag
            stop
            goto,next_file
        endif
        print,'<-- ' + file
;
; *** Parse file name for date/time info
;
        a = strsplit(file,'.',/extract)
        date = a(0)
        day = strmid(date,4,2)
        time = a(4)
        base_file = site + '_' + year + '_' + month + '_' + day + '_' + time 
        log_file = log_dir + base_file + ".log"
        cdf_file = cdf_dir + base_file + ".cdf.gz"
;
; *** Now we have the UF file. We need to rename it to test.uf for 
; *** REORDER to work correctly.
;
        spawn,'mv ' + file + ' test.uf'
;
; *** Issue the command to run REORDER
;
        command = "qreou < " + run_file + "  > " + log_file
        print,"REORDER: " + command
        spawn,command
;
; *** REORDER will create a file of the form ddop.050901.000439.cdf
; *** We want to compress it and then mv it to our CDF directory
;
        spawn,'gzip ' + 'ddop.*.cdf'
        command = 'mv ddop.*.cdf.gz ' + cdf_file
;        print,command
        spawn,command
        spawn,'rm test.uf'

next_file:
    endfor
    print,'Finished!'

;   run_reorder,'MELB','2005','09'

    stop
    end
