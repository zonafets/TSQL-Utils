/*  leave this
    l:see LICENSE file
    g:utility,script
    k:variable,table
    v:130903\s.zaglio:used fn__sql_normalize in place of fn__sql_simplify
    v:130521\s.zaglio:correction of help
    d:120508\s.zaglio:sp__script_vtable
    v:111124\s.zaglio:create declare of a variable table based on sql
*/
CREATE proc sp__script_declares
    @sql nvarchar(4000) = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @sql is null goto help

-- ============================================================== declaration ==
declare
    @tmp sysname
create table #src(lno int identity,line nvarchar(4000))

-- =========================================================== initialization ==
select
    @tmp='#'+replace(convert(sysname,newid()),'-','_'),
    @sql=dbo.fn__str_unquote(@sql,'[]')

-- ======================================================== second params chk ==
-- ===================================================================== body ==

if left(dbo.fn__sql_normalize(@sql,'sel'),7)='select '
    select @sql='select top 0 * into '+@tmp+' from ('+@sql+') a'
else
    if left(@sql,1)!='#'
        begin
        if object_id(@sql) is null goto err_nob
        select @sql='select top 0 * into '+@tmp+' from ['+@sql+']'
        end
if left(@sql,1)='#'
    begin
    if object_id('tempdb..'+@sql) is null
        goto err_nob
    else
        select @tmp=@sql
    end

insert #src(line) select 'declare @tmp table('
-- select * from fn__sql_def_cols('sysobjects',',',default)
select @sql=@sql+'
insert #src(line) select ''    ''+dbo.fn__flds_quotename(fld,default)+'' ''+def+sep from fn__sql_def_cols('''+@tmp+''','','',default) order by ord
'
exec(@sql)
insert #src(line) select ')'

exec sp__print_table '#src'

drop table #src
goto ret

-- =================================================================== errors ==
err_nob: exec @ret=sp__err 'object not found',@proc goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    script declare of a variable table
    (todo: declare variables for fields)

Parameters
    @sql    table,view,#temp table or query to use
    @opt    options
            (not used)

Examples
    sp__script_declares "sysobjects"
    sp__script_declares "select name,xtype,crdate from sysobjects"
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_vtable