/*  leave this
    l:see LICENSE file
    g:utility
    k:perf,sql
    r:120731.1000\s.zaglio: show recent query
*/
CREATE proc sp__util_sqlrecent
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp
declare
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
-- if @opt='||' goto help

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

select distinct
    db_name(dbid) db,
    object_name(objectid,dbid) obj,
    deqs.last_execution_time as [time],
    last_worker_time,min_worker_time,max_worker_time,
    dest.text as [query]
    -- ,substring(dest.text,statement_start_offset,case statement_end_offset when -1 then len(dest.text) else statement_end_offset end) stmnt
    -- ,*
from sys.dm_exec_query_stats as deqs
cross apply sys.dm_exec_sql_text(deqs.sql_handle) as dest
order by deqs.last_execution_time desc

goto help
goto ret

-- =================================================================== errors ==
/*
err_sample1:
exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param
goto ret
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    list lrecent queryes with times

Parameters
    [param]     [desc]

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__util_sqlrecent