/*  leave this
    l:see LICENSE file
    g:utility
    v:100508\s.zaglio: load/reload data from a remote server, triangulating from a 2nd rmtsvr
    c: this <- tsvr <- rmtsvr2
    t:sp__util_3load 'tbl','tsvr','rsvr',@truncate=1,@dbg=1
*/
CREATE proc sp__util_3load
    @tbl    sysname=null,
    @tsvr   sysname=null,
    @rsvr   sysname=null,
    @rdb    sysname=null,
    @truncate bit=1,
    @err    int=null out,
    @rows    bigint=null out,
    @dbg    bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__util_3load',@ret=1

if @tbl is null goto help

declare
    @tmp sysname,@sql nvarchar(4000),@db sysname,
    @trunc sysname,@sch sysname

select
    @rsvr=dbo.fn__sql_quotename(quotename(@rsvr)),
    @db=quotename(db),@sch=quotename(sch),@tbl=quotename(obj)
from dbo.fn__parsename(@tbl,default,default)

select @tbl=@sch+'.'+@tbl
if @rdb is null select @rdb=@db

select @tmp='tempdb..tmp_'+dbo.fn__str_guid(newid())
if @truncate=1 select @trunc='truncate table '+@tbl

select @sql='
use %db%
exec %tsvr%.tempdb.dbo.sp_executesql
    N"select * into %tmp% from %rsvr%.%rdb%.%tbl%"

-- dont''t look at me; it is required to elude a "Deferred prepare could not be completed"
exec("select * into %tmp% from openquery(%tsvr%,""select * from %tmp%"")")

exec %tsvr%.tempdb.dbo.sp_executesql N"drop table %tmp%"

begin tran
%truncate%
if objectproperty(object_id("%tbl%"),"TableHasIdentity")=1
    set identity_insert %tbl% on
insert into %tbl% select * from %tmp%
select @err=@@error,@rows=@@rowcount
if objectproperty(object_id("%tbl%"),"TableHasIdentity")=1
    set identity_insert %tbl% off
if @err=0 commit else rollback
drop table %tmp%
'

exec sp__str_replace @sql out,
    '"|%db%|%tsvr%|%tmp%|%rsvr%|%rdb%|%tbl%|%truncate%',
    '''',@db,@tsvr,@tmp,@rsvr,@rdb,@tbl,@trunc

if @dbg=1 print @sql
else
    exec sp_executesql @sql,N'@err int out,@rows bigint out',
                            @err=@err out,@rows=@rows out

goto ret

help:
exec sp__usage @proc,'

Scope
    load/reload data from a remote server, triangulating from a 2nd rmtsvr
'

ret:
return @ret
end -- sp__util_load