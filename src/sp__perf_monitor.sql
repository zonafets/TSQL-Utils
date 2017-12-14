/*  leave this
    l:see LICENSE file
    g:utility
    v:140109\s.zaglio:problem of cpu_ticks_in_ms in os 64bit
    r:110922\s.zaglio:sp__perf_monitor
*/
CREATE proc sp__perf_monitor
    @n tinyint = null,
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
if @opt is null goto help

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
declare
    @ts_now bigint,
    @from datetime,@to datetime,@sql int,@idle int,@other int

-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

/*
- HIGH CPU *******
      -- Isolate top waits for server instance
      WITH Waits AS
      (
        SELECT
            wait_type,
            wait_time_ms / 1000. AS wait_time_s,
            100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
            ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT LIKE '%SLEEP%'
      )
      SELECT
        W1.wait_type,
        CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s,
        CAST(W1.pct AS DECIMAL(12, 2)) AS pct,
        CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct
      FROM Waits AS W1
      INNER JOIN Waits AS W2
      ON W2.rn <= W1.rn
      GROUP BY W1.rn, W1.wait_type, W1.wait_time_s, W1.pct
      HAVING SUM(W2.pct) - W1.pct < 90 -- percentage threshold
      ORDER BY W1.rn;
*/
/*
create table #waits (type varchar(128), req bigint, waittime bigint, signal bigint)
truncate table #waits
insert into #waits exec('dbcc sqlperf(waitstats)')
    --insert into _LakeSide_DbTools_WaitsLogger_WaitsLog (DT,CPU,Locks,Reads,Writes,Network,PhReads,PhWrites,LgReads)
select
    getdate() AS DT,
    CAST(@@CPU_BUSY * CAST(@@TIMETICKS AS FLOAT) / 1000 AS BIGINT) as CPU,  -- in milliseconds
    sum(convert(bigint, case when type like 'LCK%'
      then waittime else 0 end)) as Locks,
    sum(convert(bigint, case when type like 'LATCH%'  or type like 'PAGELATCH%' or type like 'PAGEIOLATCH%'
      then waittime else 0 end)) as Reads,
    sum(convert(bigint, case when type like '%IO_COMPLETION%' or type='WRITELOG'
      then waittime else 0 end)) as Writes,
    sum(convert(bigint, case when type in ('NETWORKIO','OLEDB')
      then waittime else 0 end)) as Network,
    @@TOTAL_READ AS PhReads, @@TOTAL_WRITE AS PhWrites,
        ISNULL((select cntr_value from master.dbo.sysperfinfo where counter_name='Page lookups/sec'), 0) AS LgReads
-- select *
from #waits
truncate table #waits
insert into #waits exec('dbcc sqlperf(waitstats)')
    --insert into _LakeSide_DbTools_WaitsLogger_WaitsLog (DT,CPU,Locks,Reads,Writes,Network,PhReads,PhWrites,LgReads)
select
    getdate() AS DT,
    CAST(@@CPU_BUSY * CAST(@@TIMETICKS AS FLOAT) / 1000 AS BIGINT) as CPU,  -- in milliseconds
    sum(convert(bigint, case when type like 'LCK%'
      then waittime else 0 end)) as Locks,
    sum(convert(bigint, case when type like 'LATCH%'  or type like 'PAGELATCH%' or type like 'PAGEIOLATCH%'
      then waittime else 0 end)) as Reads,
    sum(convert(bigint, case when type like '%IO_COMPLETION%' or type='WRITELOG'
      then waittime else 0 end)) as Writes,
    sum(convert(bigint, case when type in ('NETWORKIO','OLEDB')
      then waittime else 0 end)) as Network,
    @@TOTAL_READ AS PhReads, @@TOTAL_WRITE AS PhWrites,
        ISNULL((select cntr_value from master.dbo.sysperfinfo where counter_name='Page lookups/sec'), 0) AS LgReads
-- select *
from #waits
*/

-- collect processord usage of last 4 hours
-- declare @ts_now bigint
exec sp_executesql N'
    select @ts_now = cpu_ticks / convert(float, cpu_ticks_in_ms) from sys.dm_os_sys_info
    ',N'@ts_now bigint out',@ts_now=@ts_now out

select
    record_id,
    dateadd(ms, -1 * ( @ts_now - [timestamp] ), getdate()) as eventtime,
    sqlprocessutilization,
    systemidle,
    100 - systemidle - sqlprocessutilization as otherprocessutilization
into #usage
from (
    select -- !!!! values of record.value are case sensitive
        record.value('(./Record/@id)[1]', 'int') AS record_id,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]','int') AS systemidle,
        record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sqlprocessutilization,
        timestamp
    from (
        select
            timestamp,
            convert(xml, record) as record
        from sys.dm_os_ring_buffers
        where ring_buffer_type = N'ring_buffer_scheduler_monitor'
        and record like '%%') as x
    ) as y
order by record_id desc

select
    @from=min(eventtime),
    @to=max(eventtime),
    @sql=avg(sqlprocessutilization),
    @idle=avg(systemidle),
    @other=avg(otherprocessutilization)
from #usage

if @sql is null goto err_ver

exec sp__printf '
Avg of last 4 hours of cpu usage:
    from:%s     to:%s
    mssql : %d
    idle  : %d
    other : %d',
    @from,@to,@sql,@idle,@other

select @n=30
while (@n>0)
    begin
    exec sp__printf 'Waiting for MSSQL exceed 80% of CPU usage'
    select @sql=0
    while (@sql<81)
        select top 1 @sql=sqlprocessutilization
        from (
            select -- !!!! values of record.value are case sensitive
                record.value('(./Record/@id)[1]', 'int') AS record_id,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS sqlprocessutilization
            from (
                select
                    timestamp,
                    convert(xml, record) as record
                from sys.dm_os_ring_buffers
                where ring_buffer_type = N'ring_buffer_scheduler_monitor'
                and record like '%%') as x
            ) as y
        order by record_id desc

    -- SELECT *  FROM sys.dm_os_threads  WHERE started_by_sqlservr = 0;


    -- show thread usage
    select p.spid,t.kernel_time,t.usermode_time,getdate() d,sql_handle
    into #a
    from sys.dm_os_threads t
    join master..sysprocesses p
    on p.kpid=os_thread_id
    where p.spid>50

    waitfor delay '00:00:001'

    select p.spid,t.kernel_time,t.usermode_time,getdate() d,sql_handle
    into #b
    from sys.dm_os_threads t
    join master..sysprocesses p
    on p.kpid=os_thread_id
    where p.spid>50

    select
        getdate() dt,
        a.spid,
        b.kernel_time-a.kernel_time+b.usermode_time-a.usermode_time times,
        datediff(ms,a.d,b.d) ms,
        db_name(t.dbid) db,
        object_name(t.objectid) /*,t.dbid)*/ obj,
        t.text
    into #c
    from #a a
    join #b b on a.spid=b.spid and a.sql_handle=b.sql_handle
    cross apply sys.dm_exec_sql_text (a.sql_handle) t
    where
        b.kernel_time-a.kernel_time+b.usermode_time-a.usermode_time>1000

    if @@rowcount>0
        begin
        select * from #c order by times desc
        select @n=@n-1
        end

    drop table #a drop table #b drop table #c

    -- see also sys.dm_os_workers

    end -- infinite loop

goto ret

-- =================================================================== errors ==
err_ver:
    exec @ret=sp__err 'this version of MSSQL do not support completelly ',@proc
    goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    [write here a short desc]

Parameters
    [param]     [desc]

Examples
    [exam ple]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__perf_monitor