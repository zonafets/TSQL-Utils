/*  leave this
    l:see LICENSE file
    g:utility
    v:120117\s.zaglio: func version of sp__str_replace
    t:
        select dbo.fn__str_replace(
            'test %r% and %p% and %c%',
            '%r%|%c%|%p%',
            1,getdate(),'a',
            default,default,default,default,default,default,default,default
            )
*/
create function fn__str_replace(
    @sentence nvarchar(4000)=null,
    @tokens nvarchar(4000)=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @p5 sql_variant=null,
    @p6 sql_variant=null,
    @p7 sql_variant=null,
    @p8 sql_variant=null,
    @p9 sql_variant=null,
    @p0 sql_variant=null,
    @sep nvarchar(32)
    )
returns nvarchar(4000)
as
begin
declare
    @tk1 sysname,@tk2 sysname,@tk3 sysname,@tk4 sysname,@tk5 sysname,
    @tk6 sysname,@tk7 sysname,@tk8 sysname,@tk9 sysname,@tk0 sysname

select @sep=isnull(@sep,'|')

select
    @tk1=case when pos=1  then token else @tk1 end,
    @tk2=case when pos=2  then token else @tk2 end,
    @tk3=case when pos=3  then token else @tk3 end,
    @tk4=case when pos=4  then token else @tk4 end,
    @tk5=case when pos=5  then token else @tk5 end,
    @tk6=case when pos=6  then token else @tk6 end,
    @tk7=case when pos=7  then token else @tk7 end,
    @tk8=case when pos=8  then token else @tk8 end,
    @tk9=case when pos=9  then token else @tk9 end,
    @tk0=case when pos=10 then token else @tk0 end
from dbo.fn__str_table(@tokens,@sep) t

/*
return   isnull(@tk1,'tk1')+'|'+isnull(@tk2,'tk2')+'|'
        +isnull(@tk3,'tk3')+'|'+isnull(@tk4,'tk4')+'|'
        +isnull(@tk5,'tk5')+'|'+isnull(@tk6,'tk6')+'|'
        +isnull(@tk7,'tk7')+'|'+isnull(@tk8,'tk8')+'|'
        +isnull(@tk9,'tk9')+'|'+isnull(@tk0,'tk0')+'|'
*/

if not @tk1 is null select @sentence=replace(@sentence,@tk1,convert(nvarchar(4000),@p1))
if not @tk2 is null select @sentence=replace(@sentence,@tk2,convert(nvarchar(4000),@p2))
if not @tk3 is null select @sentence=replace(@sentence,@tk3,convert(nvarchar(4000),@p3))
if not @tk4 is null select @sentence=replace(@sentence,@tk4,convert(nvarchar(4000),@p4))
if not @tk5 is null select @sentence=replace(@sentence,@tk5,convert(nvarchar(4000),@p5))
if not @tk6 is null select @sentence=replace(@sentence,@tk6,convert(nvarchar(4000),@p6))
if not @tk7 is null select @sentence=replace(@sentence,@tk7,convert(nvarchar(4000),@p7))
if not @tk8 is null select @sentence=replace(@sentence,@tk8,convert(nvarchar(4000),@p8))
if not @tk9 is null select @sentence=replace(@sentence,@tk9,convert(nvarchar(4000),@p9))
if not @tk0 is null select @sentence=replace(@sentence,@tk0,convert(nvarchar(4000),@p0))

return @sentence
end -- fn__str_replace