/*  leave this
    l:see LICENSE file
    g:utility,script
    v:120731\s.zaglio: list cols info; used by sp__script...
    t:select * from fn__script_trg(default) order by tablename,tableowner,columnid
*/
create function fn__script_trg(@tbl_id int)
returns table
return
select
       sysobjects.id,
       sysobjects.name                                                       as triggername,
       u2.name                                                               as triggerowner,
       t.name                                                                as parentname,
       t.id                                                                  as parentid,
       sysusers.name                                                         as parentowner,
       convert(bit,objectproperty(sysobjects.id,'execisupdatetrigger'))      as isupdatetrigger,
       convert(bit,objectproperty(sysobjects.id,'execisdeletetrigger'))      as isdeletetrigger,
       convert(bit,objectproperty(sysobjects.id,'execisinserttrigger'))      as isinserttrigger,
       convert(bit,objectproperty(sysobjects.id,'execisaftertrigger'))       as isaftertrigger,
       convert(bit,objectproperty(sysobjects.id,'execisinsteadoftrigger'))   as isinsteadoftrigger,
       convert(bit,objectproperty(sysobjects.id,'execisquotedidentoN'))      as quotedidentifier,
       convert(bit,objectproperty(sysobjects.id,'execisansinullsoN'))        as ansinulls,
       convert(bit,objectproperty(sysobjects.id,'execisfirstdeletetrigger')) as execisfirstdeletetrigger,
       convert(bit,objectproperty(sysobjects.id,'execisfirstinserttrigger')) as execisfirstinserttrigger,
       convert(bit,objectproperty(sysobjects.id,'execisfirstupdatetrigger')) as execisfirstupdatetrigger,
       convert(bit,objectproperty(sysobjects.id,'execislastdeletetrigger'))  as execislastdeletetrigger,
       convert(bit,objectproperty(sysobjects.id,'execislastinserttrigger'))  as execislastinserttrigger,
       convert(bit,objectproperty(sysobjects.id,'execislastupdatetrigger'))  as execislastupdatetrigger,
       convert(bit,objectproperty(sysobjects.id,'execistriggerdisabled'))    as isdisabled,
       convert(bit,objectproperty(t.id,'istable'))                           as istable,
       convert(bit,objectproperty(t.id,'isview'))                            as isview,
       syscomments.encrypted                                                 as encrypted
from     sysobjects with (nolock)
         inner join sysobjects t with (nolock)
           on t.id = sysobjects.parent_obj
         left join sysusers with (nolock)
           on sysusers.uid = t.uid
         left join sysusers u2 with (nolock)
           on u2.uid = sysobjects.uid
         left join syscomments with (nolock)
           on sysobjects.id = syscomments.id
where    sysobjects.type = 'tr'
         and isnull(syscomments.colid,1) = 1
         and (@tbl_id is null or sysobjects.parent_obj=@tbl_id)
-- end fn__script_trg