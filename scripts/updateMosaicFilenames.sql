select * into temp coinmostemp from coincident_mosaic limit 3; 

select *, substring(filename from 1 for 13)||substring(filename from 15 for 6) as newname into temp coinmosnew from coincident_mosaic limit 3;

update coinmostemp set filename = (select newname from coinmosnew where coinmosnew.filename = coinmostemp.filename);
