/*  leave this
    l:see LICENSE file
    g:utility,xls
    v:100508\s.zaglio: cerate an xls files or add a sheet to an existins
    t:sp__xls_create 'test_form','c:\backup\test_form.xls',@or=1
*/
CREATE procedure [dbo].[sp__xls_create]
    @tbl sysname,
    @xls nvarchar(512),
    @or bit=0,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc='sp__xls_create',@ret=0

declare
    @sql nvarchar(4000)

if @or=1 exec sp__drop @xls,@simul=0

select @sql=null
select @sql=coalesce(@sql+',','')+quotename(c.name)+' text' from syscolumns c where id=object_id(@tbl)
select @sql='create table ['+@tbl+']('+@sql+')'

exec sp__xls_sql @xls,@sql,@dbg=@dbg
goto ret

help:
exec sp__usage @proc,'

Parameters
    @or     if 1 delete existing file
'

ret:
return @ret
end -- sp__xls_create