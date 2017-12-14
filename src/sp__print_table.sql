/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: solved problem of print ''
    v:100501\s.zaglio: added @reverse
    v:091229\s.zaglio: added @prefix
    v:091128\s.zaglio: a small optimization
    v:091127\s.zaglio: added @format to use s__printf instead of print
    v:091018\s.zaglio: will replace part or all sp__select. Used by sp__script,sp__copy
    t:
        create table #src (lno int identity(10,10),line nvarchar(4000))
        insert #src(line) select 'hello'
        insert #src(line) select null
        insert #src(line) select 'world'
        exec sp__print_table '#src' -- ,@dbg=1
        exec sp__print_table '#src',@prefix='tst:'
        exec sp__print_table '(select lno,line from #src)',@dbg=1
        drop table #src
*/
CREATE proc [dbo].[sp__print_table]
    @tbl sysname =null,
    @autosize bit=0,
    @sizes sysname=null,     -- 20|10|5 chars
    @title sysname=null,
    @format bit=0,
    @prefix sysname=null,
    @reverse bit=0,
    @dbg bit=0
as
begin
set nocount on
declare
    @proc   sysname,
    @print  sysname,
    @sql    nvarchar(4000),@msg nvarchar(4000)

select
    @proc   ='sp__print_table'

if @tbl is null goto help
if @prefix is null
    select @print=case @format
        when 0 then 'if len(@line)=0 print char(13)+char(10) else print @line '
        else 'exec sp__printf ''%s'',@line ' end
else
    begin
    select @prefix=replace(@prefix,'''','''''')
    select @print=case @format
        when 0 then 'if len(@line)=0 print char(13)+char(10) else print '''+@prefix+'''+@line '
        else 'exec sp__printf '''+@prefix+'%s'',@line ' end
    end

select @sql ='declare @line nvarchar(4000);'
            +'declare lines cursor local for select coalesce(line,'''') as line from '+@tbl+' tbl order by lno '
            +case when @reverse=1 then 'desc;' else ';' end
            +'open lines;'
            +'while (1=1) '
            +'begin '
            +'fetch next from lines into @line '
            +'if @@error != 0 or @@fetch_status != 0 break '
            +@print
            +'end;'
            +'close lines deallocate lines;'
if not @title is null exec sp__printf @title
if @dbg=1 exec sp__printf @sql
exec(@sql)
goto ret
err_todo:
help:
select @msg='NB. actually work only for tables (lno int,line nvarchar(max))'
exec sp__usage @proc,@msg
ret:
end -- proc