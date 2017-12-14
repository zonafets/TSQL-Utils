/*  leave this
    l:see LICENSE file
    g:utility,perf
    v:120609\s.zaglio: refine
    r:120113\s.zaglio: show worst queryes
    c:
        orinally from
        http://www.databasejournal.com/features/mssql/article.php/3802936/
               Finding-the-Worst-Performing-T-SQL-Statements-on-an-Instance.htm
        written by: gregory a. larsen
        copyright © 2008 gregory a. larsen.  all rights reserved.
*/
CREATE proc sp__perf_worsts
    @opt sysname = null,
    @dbg int     = null
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==
if @opt='||' goto help

-- ============================================================== declaration ==
declare
    @dbname varchar(128),@count int,@orderby varchar(4)

-- =========================================================== initialization ==
select
    @dbname = '<not supplied>',
    @count = 999999999,
    @orderby = 'aio'
-- ======================================================== second params chk ==
-- ===================================================================== body ==

exec sp__printf '-- collecting info...'
/* check for valid @orderby parameter
if ((select case when
          @orderby in ('acpu','tcpu','ae','te','ec','aio','tio','alr','tlr','alw','tlw','apr','tpr')
             then 1 else 0 end) = 0)
begin
   -- abort if invalid @orderby parameter entered
   raiserror('@orderby parameter not apcu, tcpu, ae, te, ec, aio, tio, alr, tlr, alw, tlw, apr or tpr',11,1)
   return
 end
 */
select top (@count)
     coalesce(db_name(st.dbid),
              db_name(cast(pa.value as int))+'*',
             'resource') as [database name]
     -- find the offset of the actual statement being executed
     ,substring(text,
               case when statement_start_offset = 0
                      or statement_start_offset is null
                       then 1
                       else statement_start_offset/2 + 1 end,
               case when statement_end_offset = 0
                      or statement_end_offset = -1
                      or statement_end_offset is null
                       then len(text)
                       else statement_end_offset/2 end -
                 case when statement_start_offset = 0
                        or statement_start_offset is null
                         then 1
                         else statement_start_offset/2  end + 1
              )  as [statement]
     ,object_schema_name(st.objectid,dbid) [schema name]
     ,object_name(st.objectid,dbid) [object name]
     ,objtype [cached plan objtype]
     ,execution_count [execution count]
     ,(total_logical_reads + total_logical_writes + total_physical_reads )/execution_count [average ios]
     ,total_logical_reads + total_logical_writes + total_physical_reads [total ios]
     ,total_logical_reads/execution_count [avg logical reads]
     ,total_logical_reads [total logical reads]
     ,total_logical_writes/execution_count [avg logical writes]
     ,total_logical_writes [total logical writes]
     ,total_physical_reads/execution_count [avg physical reads]
     ,total_physical_reads [total physical reads]
     ,total_worker_time / execution_count [avg cpu]
     ,total_worker_time [total cpu]
     ,total_elapsed_time / execution_count [avg elapsed time]
     ,total_elapsed_time  [total elasped time]
     ,last_execution_time [last execution time]
into #perf_worsts
from sys.dm_exec_query_stats qs
join sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
cross apply sys.dm_exec_sql_text(qs.plan_handle) st
outer apply sys.dm_exec_plan_attributes(qs.plan_handle) pa
where attribute = 'dbid' and
 case when @dbname = '<not supplied>' then '<not supplied>'
                           else coalesce(db_name(st.dbid),
                                      db_name(cast(pa.value as int)) + '*',
                                      'resource') end
                                in (rtrim(@dbname),rtrim(@dbname) + '*')

select *
from #perf_worsts
order by
case
    when @orderby = 'acpu' then [total cpu]  / [execution count]
    when @orderby = 'tcpu'  then [total cpu]
    when @orderby = 'ae'   then [total elasped time] / [execution count]
    when @orderby = 'te'   then [total elasped time]
    when @orderby = 'ec'   then [execution count]
    when @orderby = 'aio'  then ([total logical reads] + [total logical writes] + [total physical reads]) / [execution count]
    when @orderby = 'tio'  then [total logical reads] + [total logical writes] + [total physical reads]
    when @orderby = 'alr'  then [total logical reads]  / [execution count]
    when @orderby = 'tlr'  then [total logical reads]
    when @orderby = 'alw'  then [total logical writes] / [execution count]
    when @orderby = 'tlw'  then [total logical writes]
    when @orderby = 'apr'  then [total physical reads] / [execution count]
    when @orderby = 'tpr'  then [total physical reads]
end desc

goto ret
-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    this stored procedure displays the top worst performing queries based on cpu, execution count,
    i/o and elapsed_time as identified using dmv information.  this can be display the worst
    performing queries from an instance, or database perspective.   the number of records shown,
    the database, and the sort order are identified by passing pararmeters.

Parameters
    @opt    options
            run     run collection of performance info
    @dbg    not used

Notes
    "acpu" represents average cpu usage
    "tcpu" represents total cpu usage
    "ae"   represents average elapsed time
    "te"   represents total elapsed time
    "ec"   represents execution count
    "aio"  represents average ios
    "tio"  represents total ios
    "alr"  represents average logical reads
    "tlr"  represents total logical reads
    "alw"  represents average logical writes
    "tlw"  represents total logical writes
    "apr"  represents average physical reads
    "tpr"  represents total physical read

Examples
    exec sp__perf_worsts @code=''sp__perf_worsts''
'
/*
   top 6 statements in the adventureworks database base on average cpu usage:
      exec usp_worst_tsql @dbname='adventureworks',@count=6,@orderby='acpu';

   top 100 statements order by average io
      exec usp_worst_tsql @count=100,@orderby='alr';

   show top all statements by average io
      exec usp_worst_tsql;
*/
select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- sp__perf_worsts