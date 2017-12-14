/*  leave this
    l:see LICENSE file
    g:utility
    v:130707.1000\s.zaglio: added info about wait events
    v:130222\s.zaglio: added perf code in comments for future implementation
    v:120811\s.zaglio: added comment about WMI
    v:120220.1748\s.zaglio: added io perf
    v:120104\s.zaglio: re-enabled record
    v:111011\s.zaglio: a remake
    v:111005\s.zaglio: added @waitfor
    v:110926\s.zaglio: refine
    d:110926\s.zaglio: sp__perf_top25
    v:100129\s.zaglio: print top 25 heavy processes
    t:sp__perf_old
    t:sp__perf @opt='record' select * from tmp_stat_perf order by readed desc
    t:sp_monitor
*/
CREATE proc sp__perf
    @waitfor sysname=null,
    @opt sysname=null
as
begin
set nocount on
declare @proc sysname,@ret int,@err int
select
    @err=0,@ret=0,@proc=object_name(@@procid),
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if not @waitfor is null goto err_prm
/*
130221\s.zaglio: query useful to detect perf. problem
-- select wait_type,count(*) n from sys.dm_exec_requests group by wait_type order by count(*) desc
-- select * from sys.dm_exec_requests
-- SELECT COUNT(*) AS 'Number of waiting tasks' FROM sys.dm_os_waiting_tasks;
-- SELECT COUNT(*) AS 'Number of threads' FROM sys.dm_os_waiting_tasks WHERE wait_type <> 'THREADPOOL';
-- SELECT CAST(wait_type AS VARCHAR(30)) AS 'Waiting task', COUNT (*) AS 'Number of waiting tasks' FROM sys.dm_os_waiting_tasks GROUP BY wait_type ORDER BY 'Number of waiting tasks' DESC;
-- EXEC sys.sp_configure N'max degree of parallelism'
-- select * from sys.dm_os_nodes -- mssql2k12
-- SELECT waiting_task_address AS 'Task address',session_id AS 'Session',exec_context_id AS 'Context',wait_duration_ms AS 'Wait in millsec',CAST(wait_type AS VARCHAR(30)) AS 'Type',resource_address AS 'Resource address',blocking_task_address AS 'Blocking task',blocking_session_id AS 'Blocking session',CAST(resource_description AS VARCHAR(30)) AS 'Resource' FROM sys.dm_os_waiting_tasks WHERE wait_duration_ms > 20 AND wait_type LIKE '%PAGEIOLATCH%';
-- sp__perf_monitor
-- SELECT resource_address AS 'Resource Bottleneck',COUNT (*) AS '# of bottlenecks' FROM sys.dm_os_waiting_tasks WHERE resource_address <> 0 GROUP BY resource_address ORDER BY '# of bottlenecks' DESC;
-- select 'UPDATE STATISTICS '+name+' WITH fullscan' from sysobjects where xtype='U'
-- http://blogs.msdn.com/b/cindygross/archive/2011/01/28/the-ins-and-outs-of-maxdop.aspx
-- the phisical cpu count is wrong on xeon that has 1 processor/package 4 cpus and 4 threads but 1 x cpu
-- select cpu_count as [logical cpus], hyperthread_ratio as hyperthread_ratio,cpu_count/hyperthread_ratio as physical_cpu_count,physical_memory_in_bytes/1048576 as physical_memory_in_mb from sys.dm_os_sys_info

-- if is mssql2k8
-- https://www.simple-talk.com/sql/performance/investigating-sql-server-2008-wait-events-with-xevents/

-- ms resource about perf problems
-- http://technet.microsoft.com/en-us/library/cc966540.aspx

-- simple and correct cpu use calc, tested and compared with visual graphics
declare @cpu_busy int, @idle int, @io_busy int
select @cpu_busy = @@cpu_busy, @idle = @@idle , @io_busy=@@io_busy
waitfor delay '000:00:01'
select
    (@@cpu_busy - @cpu_busy)/((@@idle - @idle + @@cpu_busy - @cpu_busy) *1.00) *100 as 'cpu',
    (@@io_busy - @io_busy)/((@@idle - @idle + @@io_busy - @io_busy) *1.00) *100 as 'io'

-- Total waits are wait_time_ms (high signal waits indicates CPU pressure)
-- if pct signal wait > 10%, means that more cpu are required
SELECT CAST(100.0 * SUM(signal_wait_time_ms) / SUM(wait_time_ms) AS NUMERIC(20,2)) AS [%signal (cpu) waits] , CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / SUM(wait_time_ms) AS NUMERIC(20, 2)) AS [%resource waits]FROM sys.dm_os_wait_stats ;

-- Isolate top waits for server instance since last restart
-- or statistics clear
WITH Waits AS ( SELECT wait_type , wait_time_ms / 1000. AS wait_time_s , 100. * wait_time_ms / SUM(wait_time_ms) OVER ( ) AS pct ,
ROW_NUMBER() OVER ( ORDER BY wait_time_ms DESC ) AS rn FROM sys.dm_os_wait_stats WHERE wait_type NOT IN ( 'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BROKER_TO_FLUSH', 'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT', 'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE', 'FT_IFTS_SCHEDULER_IDLE_WAIT', 'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN' ) ) SELECT W1.wait_type , CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s , CAST(W1.pct AS DECIMAL(12, 2)) AS pct , CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct FROM Waits AS W1 INNER JOIN Waits AS W2 ON W2.rn <= W1.rn GROUP BY W1.rn , W1.wait_type , W1.wait_time_s , W1.pct HAVING SUM(W2.pct) - W1.pct < 95 ; -- percentage threshold

-- Recovery model, log reuse wait description, log file size,
-- log usage size and compatibility level for all databases on instance
SELECT db.[name] AS [Database Name] , db.recovery_model_desc AS [Recovery Model] , db.log_reuse_wait_desc AS [Log Reuse Wait Description] , ls.cntr_value AS [Log Size (KB)] ,
lu.cntr_value AS [Log Used (KB)] , CAST(CAST(lu.cntr_value AS FLOAT) / CAST(ls.cntr_value AS FLOAT) AS DECIMAL(18,2)) * 100 AS [Log Used %] , db.[compatibility_level] AS [DB Compatibility Level] , db.page_verify_option_desc AS [Page Verify Option]
FROM sys.databases AS db
INNER JOIN sys.dm_os_performance_counters AS lu
    ON db.name = lu.instance_name
INNER JOIN sys.dm_os_performance_counters AS ls
    ON db.name = ls.instance_name
WHERE lu.counter_name LIKE 'Log File(s) Used Size (KB)%' AND ls.counter_name LIKE 'Log File(s) Size (KB)%' ;

---- average stalls per read, write and total
---- adding 1.0 to avoid division by zero errors
select db_name(database_id) db, file_id
    ,io_stall_read_ms
    ,num_of_reads
    ,cast(io_stall_read_ms/(1.0+num_of_reads) as numeric(10,1)) as 'avg_read_stall_ms'
    ,io_stall_write_ms
    ,num_of_writes
    ,cast(io_stall_write_ms/(1.0+num_of_writes) as numeric(10,1)) as 'avg_write_stall_ms'
    ,io_stall_read_ms + io_stall_write_ms as io_stalls
    ,num_of_reads + num_of_writes as total_io
    ,cast((io_stall_read_ms+io_stall_write_ms)/(1.0+num_of_reads + num_of_writes) as numeric(10,1)) as 'avg_io_stall_ms'
from sys.dm_io_virtual_file_stats(null,null)
order by avg_io_stall_ms desc

-- transactions x second
declare @n int
select @n=cntr_value
from sys.dm_os_performance_counters
where counter_name = 'transactions/sec'
and rtrim(object_name) like '%:databases'
and instance_name = db_name()
waitfor delay '00:00:01'
select (cntr_value-@n)/1
from sys.dm_os_performance_counters
where counter_name = 'transactions/sec'
and rtrim(object_name) like '%:databases'
and instance_name = db_name()

*/

/*

    DBCC SQLPERF (Waitstats)
        PAGELATCH_EX indicated waits for physical I/O
        CXPACKET indicates waits for parallel processes to complete.
        NETWORKIO indicates waits for Network I/O

        For NETWORKIO, use perfmon to determine the workload and if there is sufficient thruput available.
        For CXPACKET, if this is primarily OLTP transactions, suggest disabling parallelism (max degree of 1 ).
        For PAGELATCH_EX, suggest you gather database file I/O statistics on a regular basis to determine if there is a disk resource problem:

    select db_name(dbid) db,IoStallMS / ( NumberReads + NumberWrites ) as MsPerIo,*
    from :: fn_virtualfilestats(default,default)
    order by IoStallMS / ( NumberReads + NumberWrites ) desc

        The statistics are since the SQL Server was started,
        so you will need to determine the changes between two sets of statistics yourself.
        MsPerIo should be under 8 and under 4 is desirable. Also use perfmon to check the disk queue length.

        I second Grant Fritchey's recommendation to run a trace.
        There are MS provided tools to analyze the traces that are not very friendly (obtuse command line switches )
        but the results are incredibly useful and almost impossible to produce manually.
        http://support.microsoft.com/kb/944837

    Consider this http://thomaslarock.com/2011/01/wmi-code-creator/ about WMI
    but it does not work in production and return an absurd value.

*/
-- 5/6/2003 sp - sqlhogs 2.0
-- modify below to proper number of processors
--   (hyperthreaded and multi-core count so probably just see how many show in task mgr)
-- 2/2/07 sp - modified to sum for ecids per spid, as opposed to just showing ecit=0
-- grabs two snapshots from sysperfinfo and presents a delta between them
-- to estimate sql server usage.
declare
    @icpucount int,
    @cpu_busy bigint, @idle_busy bigint,@io_busy bigint,
    @cpu numeric(32,2), @idle numeric(32,2),@io numeric(32,2),
    @secfromstart numeric (18,2),
    @dt datetime,@s int,
    @record bit

select
    @record=charindex('|record|',@opt),
    @dt=getdate(),
    @secfromstart =
        datediff(s, (
            select top 1 login_time  -- start time of the instance
            from master..sysprocesses
            where cmd='lazy writer'
            ),
            getdate()
        )

exec('
create proc #iostats_fill
as
insert #iostats
select *
from (
    select
        getdate() as capture_time,
        --virtual file latency
        readlatency = case when num_of_reads = 0
            then 0 else (io_stall_read_ms / num_of_reads) end,
        writelatency = case when num_of_writes = 0
            then 0 else (io_stall_write_ms / num_of_writes) end,
        latency = case when (num_of_reads = 0 and num_of_writes = 0)
            then 0 else (io_stall / (num_of_reads + num_of_writes)) end,
        --avg bytes per iop
        avgbperread = case when num_of_reads = 0
            then 0 else (num_of_bytes_read / num_of_reads) end,
        avgbperwrite = case when io_stall_write_ms = 0
            then 0 else (num_of_bytes_written / num_of_writes) end,
        avgbpertransfer = case when (num_of_reads = 0 and num_of_writes = 0)
            then 0 else ((num_of_bytes_read + num_of_bytes_written) /
                (num_of_reads + num_of_writes)) end,
        left (mf.physical_name, 2) as drive,
        db_name (vfs.database_id) as db,
        --vfs.*,
        substring(
            mf.physical_name,
            len(mf.physical_name)-
                charindex(''\'',reverse(mf.physical_name))+2, 100
            )
        as file_name,
        num_of_writes+num_of_reads nwr
    -- select *
    from sys.dm_io_virtual_file_stats (null,null) as vfs
    join sys.master_files as mf
        on vfs.database_id = mf.database_id
        and vfs.file_id = mf.file_id
    ) vfs
where 1=1
    and latency>50
-- vfs.file_id = 2 -- log files
-- order by latency desc
-- order by readlatency desc
-- order by writelatency desc;
')
-- drop table #iostats
create table #iostats (
    capture_time    datetime,
    readlatency     bigint null,
    writelatency    bigint null,
    latency         bigint null,
    avgbperread     bigint null,
    avgbperwrite    bigint null,
    avgbpertransfer bigint null,
    drive           nvarchar(2)  null,
    db              nvarchar(128)  null,
    file_name       nvarchar(100)  null,
    nwr             bigint null
    )

-- get number of processors
/*
select  @icpucount=cpu_count / hyperthread_ratio as physical_cpu_sockets
from    sys.dm_os_sys_info ;
*/
create table #numprocs
(
        id int,
        colname varchar(128),
        iv int,
        cv varchar(128)
)

exec('exec #iostats_fill')

select @waitfor='%'+@waitfor+'%'
while (1=1)
    begin

    insert #numprocs
            exec master..xp_msver
    select @icpucount = iv from #numprocs
            where colname like '%processorcount%'
    drop table #numprocs

    -- dbcc inputbuffer(spid) - shows the command that was run
    -- spid = sql server process id.
    -- kpid = windows thread id.  the thread id shows the kpid for a given sql server thread.
    -- blocked = spid of the blocking process.
    -- waittime = ms.
    -- dbid = database id
    -- uid = user id
    -- cpu = ms
    -- physical io = physical reads and writes
    -- memusage = number of pages in proc cache for this spid
    -- last_batch = time of last exec or stored proc
    -- ecid = identifies subthreads within a spid

    -- get the two snapshots, 1 second apart.
    -- exclude user = system.
    select 1 as snapnum, spid, kpid, blocked,
        waittime, dbid, uid, cpu,
        physical_io, memusage, login_time, last_batch,
        ecid, status, hostname, program_name,
        cmd, net_address, loginame, getdate() as snaptime,
        sql_handle,stmt_start,stmt_end,lastwaittype,waitresource
      into #snapshot
      from master..sysprocesses
        where uid >= 0

    select @cpu_busy = @@cpu_busy, @idle_busy = @@idle,@io_busy=@@io_busy
    waitfor delay '00:00:01' -- sp__perf
    select
        @cpu=   (cast(@@cpu_busy as float)- @cpu_busy)/
                ((@@idle - @idle_busy + @@cpu_busy - @cpu_busy+0.001) *1.00)
                *100.0,
        @io=    (cast(@@io_busy as float)- @io_busy)/
                1000.00 *100.0,
        @idle=  (cast(@@io_busy as float)- @io_busy)/
                ((@@idle - @idle_busy + @@io_busy - @io_busy+0.001) *1.00) *100.0

    insert into #snapshot
      select 2 as snapnum, spid, kpid, blocked,
        waittime, dbid, uid, cpu,
        physical_io, memusage, login_time, last_batch,
        ecid, status, hostname, program_name,
        cmd, net_address, loginame, getdate() as snaptime,
        sql_handle,stmt_start,stmt_end,lastwaittype,waitresource
        from master..sysprocesses
        where uid >= 0

    -- join the two snapshots, dropping ecid's that were missing from one or the other.
    -- just do the columns that require a delta for performance.
    select
        s1.spid as s1_spid, s1.ecid as s1_ecid,
        s1.waittime as s1_waittime, s1.cpu as s1_cpu,
        s1.physical_io as s1_physical_io, s1.snaptime as s1_snaptime,
        s2.waittime as s2_waittime, s2.cpu as s2_cpu,
        s2.physical_io as s2_physical_io, s2.snaptime as s2_snaptime
      into #snapboth
      from #snapshot as s1 join #snapshot as s2
        on s1.spid = s2.spid
          and s1.ecid = s2.ecid
          and s1.snapnum = 1
          and s2.snapnum = 2

    -- get the difference between the 2 snapshots, ms per ecid
    -- this is ( / 1000 * 100 ).
    select s1_spid as spid, s1_ecid as ecid,
        sum( s2_waittime - s1_waittime ) as waitmsperecid,
        sum( s2_cpu - s1_cpu ) as cpumsperecid,
        sum( s2_physical_io - s1_physical_io ) as deltaioperecid
      into #perfdeltaperecid
      from #snapboth
      group by s1_spid, s1_ecid

    -- and sum those across per spid.
    select spid,
        sum( waitmsperecid ) as waitms,
        sum( cpumsperecid ) as cpums,
        sum( deltaioperecid ) as deltaio
      into #perfdelta
      from #perfdeltaperecid
      group by spid

    -- show the results for the cpu hogs.
    -- cpu conversion is ms to sec and then to percent / cpus.
    select top 5
        @dt as readed,
        @cpu [scpu%],@io [io%], @idle [io_idle%],
        convert( integer, pd.cpums * 0.001 * 100.0 / @icpucount ) as [pcpu%],
        pd.deltaio as [dIO], lcks.n dls,
        pd.spid, ss.kpid, convert( varchar(16), ss.loginame ) as username,
        case
            when ss.program_name like 'sqlagent - tsql jobstep (job %'
            then (
                select top 1 j.name
                from msdb..sysjobs j
                where
                    rtrim(ltrim(dbo.fn__str_between(ss.program_name,'job ',' :',default)))
                    =
                    dbo.fn__hex(convert(varbinary,job_id))
                )
            else object_name((select top 1 objectid from ::fn_get_sql(ss.sql_handle)))
        end obj,
        substring((select top 1 text from ::fn_get_sql(ss.sql_handle)),
            coalesce(nullif(case ss.stmt_start when 0 then 0 else ss.stmt_start / 2 end, 0), 1),
            case (case ss.stmt_end when -1 then -1 else ss.stmt_end / 2 end)
                when -1
                        then datalength((select top 1 text from ::fn_get_sql(ss.sql_handle)))
                else
                        ((case ss.stmt_end when -1 then -1 else ss.stmt_end / 2 end) -
                         (case ss.stmt_start when 0 then 0 else ss.stmt_start / 2 end)
                        )
                end
        ) as [sql],
        ss.cmd,
        convert( varchar(15), ss.hostname ) as host, convert( varchar(15), ss.program_name ) as program,
        ( select name from master..sysdatabases where dbid = ss.dbid ) as db,
        ss.status, ss.login_time, ss.last_batch,
        ss.net_address,lastwaittype lwr,waitresource wr
      into #out
      from #perfdelta as pd join #snapshot as ss
          on pd.spid = ss.spid
            and ss.ecid = 0
            and ss.snapnum = 1
      left join  (
        select count(*) as n, resource_database_id dbid
        from master.sys.dm_tran_locks
        group by resource_database_id
        ) lcks on lcks.dbid=ss.dbid
      where cpums > 5
      and pd.spid!=@@spid -- and pd.spid>50 -- to exclude system spid
      order by (cpums+deltaio)/2 desc

    -- output result
    if @record=0
        begin
        select * from #out

        exec('exec #iostats_fill')

        -- query 5: compute the total number of reads and writes.
        select
            t2.readlatency,t2.writelatency,t2.latency,
            t2.avgbperread,t2.avgbperwrite,t2.avgbpertransfer,
            t2.db,t2.drive,t2.file_name
        from    #iostats t1
        join    #iostats t2
        on      t1.db=t2.db and t1.file_name=t2.file_name
        and     t1.capture_time < t2.capture_time
        where   t2.nwr - t1.nwr > 0
        order by latency desc

        end -- record = 0
    else
        begin
        if object_id('tmp_stat_perf') is null
            select identity(int,1,1) id,*
            into tmp_stat_perf
            from #out
        else
            insert tmp_stat_perf
            select * from #out
        end -- record

    break -- one day will re-implement waitfor
    end -- while

drop proc  #iostats_fill
drop table #perfdeltaperecid
drop table #perfdelta
drop table #snapboth
drop table #snapshot

/*

-- turn the raw statistics into rates
select cast(cast(@@total_read as numeric (18,2))/@secfromstart
               as numeric (18,2))  as [reads/sec]
     , cast(cast(@@total_write as numeric (18,2))/@secfromstart
               as numeric (18,2)) as [writes/sec]
     , cast(@@io_busy * cast(@@timeticks as numeric(18,2))/10000.0/@secfromstart
               as numeric (18,2)) as [percent i/o time]
*/

goto help

err_prm:    exec @ret=sp__err 'parameter gived for compatibility but not working',@proc
            goto ret

help:
exec sp__printf '
Scope
    get processes performance with info

Parameters
    @waitfor    (TODO) wait until this word appear in the sql code or obj name
    @opt        options
                record      store data into table tmp_stat_perf

Fields description
    scpu%:  is the whole server cpu usage
    pcpu%:  is the single process cpu usage
    dIO:    is the delta IO milliseconds
    dls:    database locks
    status: Process ID status. The possible values are:
        dormant     SQL Server is resetting the session.
        running     The session is running one or more batches.
                    When Multiple Active Result Sets (MARS) is enabled, a session can run multiple batches.
                    For more information, see Using Multiple Active Result Sets (MARS).
        background  The session is running a background task, such as deadlock detection.
        rollback    The session has a transaction rollback in process.
        pending     The session is waiting for a worker thread to become available.
        runnable    The task in the session is in the runnable queue of a scheduler while waiting to get a time quantum.
        spinloop    The task in the session is waiting for a spinlock to become free.
        suspended   The session is waiting for an event, such as I/O, to complete.
    lwr (lastwaittype):
    CXPACKET
        Often indicates nothing more than that certain queries are executing
        with parallelism; CXPACKET waits in the server are not an immediate
        sign of problems, although they may be the symptom of another problem,
        associated with one of the other high value wait types in the instance.
    SOS_SCHEDULER_YIELD
        The tasks executing in the system are yielding the scheduler, having
        exceeded their quantum, and are having to wait in the runnable queue
        for other tasks to execute. This may indicate that the server is under
        CPU pressure.
    THREADPOOL
        A task had to wait to have a worker bound to it, in order to execute.
        This could be a sign of worker thread starvation, requiring an increase
        in the number of CPUs in the server, to handle a highly concurrent
        workload, or it can be a sign of blocking, resulting in a large number
        of parallel tasks consuming the worker threads for long periods.
    LCK_*
        These wait types signify that blocking is occurring in the system and
        that sessions have had to wait to acquire a lock of a specific type,
        which was being held by another database session. This problem can be
        investigated further using, for example, the information in the
        sys.dm_db_index_operational_stats.
    PAGEIOLATCH_*, IO_COMPLETION, WRITELOG
        These waits are commonly associated with disk I/O bottlenecks, though
        the root cause of the problem may be, and commonly is, a poorly
        performing query that is consuming excessive amounts of memory in the
        server. PAGEIOLATCH_* waits are specifically associated with delays in
        being able to read or write data from the database files.
    WRITELOG
        waits are related to issues with writing to log files. These waits
        should be evaluated in conjunction with the virtual file statistics
        as well as Physical Disk performance counters, to determine if the
        problem is specific to a single database, file, or disk, or is instance
        wide.
    PAGELATCH_*
        Non-I/O waits for latches on data pages in the buffer pool. A lot of
        times PAGELATCH_* waits are associated with allocation contention issues.
        One of the best-known allocations issues associated with PAGELATCH_*
        waits occurs in tempdb when the a large number of objects are being
        created and destroyed in tempdb and the system experiences contention
        on the Shared Global Allocation Map (SGAM), Global Allocation Map (GAM),
        and Page Free Space (PFS) pages in the tempdb database.
    LATCH_*
        These waits are associated with lightweight short-term synchronization
        objects that are used to protect access to internal caches, but not the
        buffer cache. These waits can indicate a range of problems, depending on
        the latch type. Determining the specific latch class that has the most
        accumulated wait time associated with it can be found by querying the
        sys.dm_os_latch_stats DMV.
    ASYNC_NETWORK_IO
        This wait is often incorrectly attributed to a network bottleneck. In
        fact, the most common cause of this wait is a client application that
        is performing row-by-row processing of the data being streamed from SQL
        Server as a result set (client accepts one row, processes, accepts next
        row, and so on). Correcting this wait type generally requires changing
        the client-side code so that it reads the result set as fast as possible,
        and then performs processing.
'
ret:
return @ret
end -- sp__perf