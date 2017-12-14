/*  leave this
    l:see LICENSE file
    g:utility,script
    v:110628\s.zaglio: added scripting of trigger db
    v:110406\s.zaglio: removed @out
    v:100919\s.zaglio: adapted to mssql2k
    v:100404\s.zaglio: script properties
    t:
        exec sp__comment '[sp__script_prop]','test sp..scr..prp'
        exec sp__comment '[sp__script_prop].[@obj]','test sp..scr..prp'
        exec sp__script_prop 'sp__script_prop'
*/
CREATE proc [dbo].[sp__script_prop]
    @obj sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if @obj is null goto help

if dbo.fn__isMSSQL2K()=1
    begin
    raiserror('warning!! sp__Script_prop not compatible with mssql2k',16,1)
    goto ret
    end

if @dbg=1 exec sp__printf '-- sp__script_prop scope'

declare
    @step int,@type nvarchar(2),
    @db sysname,@sch sysname,@sch_id int,
    @obj_ex sysname,@obj_in sysname,
    @sql nvarchar(4000),
    @lno_begin int,@lno_end int,
    @id int

declare @src table(lno int identity primary key,line nvarchar(4000))

select
    @db =parsename(@obj,3),
    @sch=parsename(@obj,2),
    @obj=parsename(@obj,1)
if @db is null select @db=db_name()
select @sch=[name],@sch_id=id from dbo.fn__schema_of(@obj)
select @obj_ex=quotename(@db)+'.'+coalesce(quotename(@sch),'')+'.'+quotename(@obj)

select @id=object_id(@obj_ex)
if @id is null and dbo.fn__isMSSQL2K()=0
    select @id=object_id from sys.triggers where [name]=@obj

if @id=0 goto err_nof


select @step=ident_incr('tempdb..#src')

insert @src(line)
select 'exec sp__comment '''+quotename(@obj)+coalesce('.'+quotename(column_name),'')+''','+
                         ''''+replace(convert(nvarchar(4000),[value]),'''','''''')+''''
from dbo.fn__comments(null) where obj_id=object_id(@obj_ex)

if object_id('tempdb..#src') is null
    select line from @src order by lno
else
    insert #src(line) select line from @src order by lno

goto ret

-- =================================================================== errors ==
err_nof:    exec @ret=sp__err 'object %s not found',@proc,@p1=@obj_ex goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc
select @ret=-1

ret:
return @ret
end -- sp__script_prop