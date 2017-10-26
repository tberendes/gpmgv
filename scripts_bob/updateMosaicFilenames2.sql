select *, substring(filename from 1 for 13)||substring(filename from 15 for 6) as newname into temp coinmosnew from coincident_mosaic;

update coincident_mosaic set filename = (select newname from coinmosnew where coinmosnew.filename = coincident_mosaic.filename);

--not tested
