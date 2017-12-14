/*  leave this
    l:see LICENSE file
    g:utility
    k:street, place, constant, type, at
    v:121016\s.zaglio: list "at" type of places
    t:select * from fn__place_at()
*/
CREATE function fn__place_at()
returns table
with schemabinding
as
return
select 1 lng,1 id,0 rid,'C/O' cod       -- presso
union select 1,2,1,'PRESSO'
union select 1,3,1,'P/O'       -- presso
union select 1,4,1,'CASA DI RIPOSO'
union select 1,5,1,'REPARTO'
union select 1,6,1,'CENTRO DI RIABILITAZIONE'
union select 1,7,1,'RSA'
union select 1,8,1,'C\O'

-- end fn__place_at