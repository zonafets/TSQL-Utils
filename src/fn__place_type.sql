/*  leave this
    l:see LICENSE file
    g:utility
    k:street, place, constant, type
    v:121016\s.zaglio: list type of places
    t:select * from fn__place_type()
*/
CREATE function fn__place_type()
returns table
with schemabinding
as
return
select 1 lng,1 id,0 rid,'CASELLA POSTALE' cod
union select 1,2,0,'CONTRADA'
union select 1,3,0,'CORSO'
union select 1,4,0,'FRAZIONE'
union select 1,5,0,'LIDO'
union select 1,6,0,'LOCALITÀ'
union select 1,7,0,'LUNGOMARE'
union select 1,8,0,'MOLO'
union select 1,9,0,'OSPEDALE'
union select 1,10,0,'PASSEGGIATA'
union select 1,11,0,'PIAZZA'
union select 1,12,0,'RACCORDO'
union select 1,13,0,'RIONE'
union select 1,14,0,'SCALO'
union select 1,15,0,'STRADA'
union select 1,16,0,'STRADINA'
union select 1,17,0,'STRADONE'
union select 1,18,0,'VIA'
union select 1,19,0,'VIALE'
union select 1,20,0,'VICOLO'
union select 1,21,0,'ZONA'
union select 1,22,2,'C.DA'
union select 1,23,3,'C.SO'
union select 1,24,11,'P.ZZA'
union select 1,25,11,'PZZA'
union select 1,26,19,'V.LE'
union select 1,27,0,'PIAZZALE'
union select 1,28,0,'VICO'
union select 1,29,4,'FRAZ.'
union select 1,31,0,'LARGO'
union select 1,32,0,'VILLA'
union select 1,33,31,'L.GO'
union select 1,34,18,'V.'
union select 1,35,6,'LOCALITA'''
union select 1,36,15,'STD'
union select 1,37,0,'BORGO'
union select 1,38,37,'BGO'
union select 1,39,15,'S.DA'
union select 1,40,11,'P.ZA'
union select 1,41,0,'PIAZZETTA'
union select 1,42,41,'P.TTA'
union select 1,44,0,'TRAVERSA'
union select 1,45,44,'TRAV.'
union select 1,46,18,'VIA.'
-- union select 1,45,0,'C/O'       -- presso
-- union select 1,46,45,'PRESSO'
union select 1,47,3,'C/SO'       -- corso
union select 1,48,0,'LOC.'
union select 1,49,2,'C/DA'
union select 1,50,2,'CONTR.'
union select 1,51,3,'CSO'       -- corso
--union select 1,52,45,'P/O'       -- presso
union select 1,53,0,'DISTRETTO'
union select 1,54,0,'CORTE'
union select 1,55,19,'VLE'
union select 1,56,37,'B.GO'
union select 1,57,11,'P.'
union select 1,58,2,'CDA'
union select 1,59,15,'STR.COMUNALE'
union select 1,60,15,'STR.'
union select 1,61,3,'C.'
union select 1,62,0,'CENTRO DIREZIONALE'
union select 1,63,0,'PARCO'
union select 1,64,0,'GALLERIA'
union select 1,65,63,'PCO'       -- parco
union select 1,66,0,'POLICLINICO'
union select 1,67,0,'FARMACIA COMUNALE'
union select 1,68,0,'FARMACIA'
union select 1,69,67,'FARM.COMUN.'
union select 1,70,0,'CORTILE'
union select 1,71,32,'VILL.'
union select 1,72,48,'LOC'
union select 1,73,3,'C.SO'       -- corso
union select 1,74,0,'BORGATA'
union select 1,75,74,'B.TA'
-- union select 1,76,0,'CASA DI RIPOSO'    -- è un C/O, vedere fn__place_at
union select 1,77,0,'PASSAGGIO PRIVATO'
union select 1,78,15,'ST.'
union select 1,79,15,'STR'
union select 1,80,15,'STRDA'
union select 1,81,7,'L.MARE'
union select 1,82,7,'LG.MARE'
union select 1,83,2,'CONT.DA'
union select 1,84,2,'CON.DA'
union select 1,85,0,'CIRCONVALLAZIONE'
union select 1,86,0,'CENTRO COMMERCIALE'
union select 1,87,86,'CENTRO COMM.LE'
union select 1,88,45,'VICINO'
union select 1,89,0,'SALITA'
union select 1,90,0,'REGIONE'
union select 1,91,0,'CASCINA'
union select 1,94,0,'CENTRO VACANZE'  -- è un C/O, verificare presenza di name
union select 1,95,0,'RUE'   -- paesi di confine francese
-- end fn__place_type