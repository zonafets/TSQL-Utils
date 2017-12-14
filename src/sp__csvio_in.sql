/*  leave this
    l:see LICENSE file
    g:utility
    v:100509\s.zaglio: inport a txt file into a table with csvio
    t:sp__csvio_in 'c:\autoexec.bat','test'
*/
CREATE proc [dbo].[sp__csvio_in]
    @path   nvarchar(512)=null,
    @out    sysname=null,
    @def    sysname=null,
    @dbg    bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__csvio_in',@ret=0

if @path is null and @out is null goto help

if @def is null select @def=@out

if not exists(select null from csvio where tid=1 and des=@def) goto err_def

-- declaration
declare
    @tid tinyint,
    @sql nvarchar(4000)

create table #src(lno int identity,line nvarchar(4000))

-- init and addjust

select
    @tid=1

create table #vars (id nvarchar(16),value sql_variant)
insert #vars values('"',        '''')

-- inport text (read utf8/unix/win txt files)
exec sp__file_read_stream @path,@out='#src',@dbg=@dbg

-- filter columns
select @sql=null
select @sql =coalesce(@sql+',','')+'substring(line,'+convert(sysname,idx)+','+convert(sysname,n)+') '
            +quotename(cod)
from csvio
where tid=@tid
and des=@def

if @out is null
    select @sql='select '+@sql+' from #src order by lno'
else
    select @sql='insert '+@out+' select '+@sql+' from #src order by lno'

if @dbg=1 exec sp__printf '%s',@sql
else exec(@sql)

drop table #src

goto ret

err_def:    exec @ret=sp__err 'definition "%s" not found',@proc,@p1=@def    goto ret

help:
exec sp__usage @proc,'
'
select @ret=-1

ret:
return @ret
end -- sp__csvio