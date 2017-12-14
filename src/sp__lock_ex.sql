/*  leave this
    l:see LICENSE file
    g:utility
    v:130203\s.zaglio: added cxpackets locks
    v:120911\s.zaglio: added warning on missing help
    v:120905\s.zaglio: added code for finding the SPID of running jobs
    v:111213\s.zaglio: blocking into #temp because out of memory
    v:111129\s.zaglio: added view of blocking in current database
    v:110921\s.zaglio: emaciated
    v:110916\s.zaglio: added list of n locks x db
    v:101110\s.zaglio: removed original_login_name,original_security_id(sp3) to make it compatible with sp2
    v:101012\s.zaglio: not tested but probably better than my sp__lock
    t:exec sp__lock_ex ; exec sp__lock_ex @procdata='a'
    c:
        originally from http://www.sommarskog.se/sqlutil/beta_lockinfo.sp
        i removed comments and text mode to reduce compile time
*/
CREATE proc sp__lock_ex
    @allprocesses bit     = 0,
    @procdata     char(1) = null,
    @debug        bit     = 0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

if dbo.fn__ismssql2k()=0
    begin

    -- cx packets locks
    select session_id
            , exec_context_id
            , wait_type
            , wait_duration_ms
            , blocking_session_id
    from sys.dm_os_waiting_tasks
    where session_id > 50
    order by session_id, exec_context_id

    -- number of lock records per database
    select count(*) as 'numberoflockrecords', db_name(resource_database_id)
    from master.sys.dm_tran_locks
    group by resource_database_id;

-- ========================================= finding the SPID of running jobs ==
    -- from http://social.msdn.microsoft.com/Forums/eu/transactsql/thread/8af7ac39-7b09-4b84-9c1c-95573c7350d8
    DECLARE @record_id int, @SQLProcessUtilization int, @CPU int,@EventTime datetime--,@MaxCPUAllowed int
    select  top 1  @record_id =record_id,
          @EventTime=dateadd(ms, -1 * ((SELECT ms_ticks from sys.dm_os_sys_info) - [timestamp]), GetDate()),-- as EventTime,
          @SQLProcessUtilization=SQLProcessUtilization,
          --SystemIdle,
          --100 - SystemIdle - SQLProcessUtilization as OtherProcessUtilization,
          @CPU=SQLProcessUtilization + (100 - SystemIdle - SQLProcessUtilization) --as CPU_Usage
    from (
          select
                record.value('(./Record/@id)[1]', 'int') as record_id,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') as SystemIdle,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') as SQLProcessUtilization,
                timestamp
          from (
                select timestamp, convert(xml, record) as record
                from sys.dm_os_ring_buffers
                where ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                and record like '%<SystemHealth>%') as x
          ) as y
    order by record_id desc
    SELECT
            x.session_id as [Sid],
            COALESCE(x.blocking_session_id, 0) as BSid,
            @CPU as CPU,
            @SQLProcessUtilization as SQL,

            x.Status,
            x.TotalCPU as [T.CPU],
            x.Start_time,
            CONVERT(nvarchar(30), getdate()-x.Start_time, 108) as Elap_time, --x.totalElapsedTime as ElapTime,
            x.totalReads as [T.RD], -- total reads
            x.totalWrites as [T.WR], --total writes
            x.Writes_in_tempdb as [W.TDB],
            (
                  SELECT substring(text,x.statement_start_offset/2,
                        (case when x.statement_end_offset = -1
                        then len(convert(nvarchar(max), text)) * 2
                        else x.statement_end_offset end - x.statement_start_offset+3)/2)
                  FROM sys.dm_exec_sql_text(x.sql_handle)
                  FOR XML PATH(''), TYPE
            ) AS Sql_text,
            db_name(x.database_id) as dbName,
            (SELECT object_name(objectid) FROM sys.dm_exec_sql_text(x.sql_handle)) as object_name,
            x.Wait_type,
            x.Login_name,
            x.Host_name,
            CASE LEFT(x.program_name,15)
            WHEN 'SQLAgent - TSQL' THEN
            (     select top 1 'SQL Job = '+j.name from msdb.dbo.sysjobs (nolock) j
                  inner join msdb.dbo.sysjobsteps (nolock) s on j.job_id=s.job_id
                  where right(cast(s.job_id as nvarchar(50)),10) = RIGHT(substring(x.program_name,30,34),10) )
            WHEN 'SQL Server Prof' THEN 'SQL Server Profiler'
            ELSE x.program_name
            END as Program_name,
            x.percent_complete,
            x.percent_complete,
            (
                  SELECT
                        p.text
                  FROM
                  (
                        SELECT
                             sql_handle,statement_start_offset,statement_end_offset
                        FROM sys.dm_exec_requests r2
                        WHERE
                             r2.session_id = x.blocking_session_id
                  ) AS r_blocking
                  CROSS APPLY
                  (
                  SELECT substring(text,r_blocking.statement_start_offset/2,
                        (case when r_blocking.statement_end_offset = -1
                        then len(convert(nvarchar(max), text)) * 2
                        else r_blocking.statement_end_offset end - r_blocking.statement_start_offset+3)/2)
                  FROM sys.dm_exec_sql_text(r_blocking.sql_handle)
                  FOR XML PATH(''), TYPE
                  ) p (text)
            )  as blocking_text,
            (SELECT object_name(objectid) FROM sys.dm_exec_sql_text(
            (select top 1 sql_handle FROM sys.dm_exec_requests r3 WHERE r3.session_id = x.blocking_session_id))) as blocking_obj

      FROM
      (
            SELECT
                  r.session_id,
                  s.host_name,
                  s.login_name,
                  r.start_time,
                  r.sql_handle,
                  r.database_id,
                  r.blocking_session_id,
                  r.wait_type,
                  r.status,
                  r.statement_start_offset,
                  r.statement_end_offset,
                  s.program_name,
                  r.percent_complete,
                  SUM(cast(r.total_elapsed_time as bigint)) /1000 as totalElapsedTime, --CAST AS BIGINT to fix invalid data convertion when high activity
                  SUM(cast(r.reads as bigint)) AS totalReads,
                  SUM(cast(r.writes as bigint)) AS totalWrites,
                  SUM(cast(r.cpu_time as bigint)) AS totalCPU,
                  SUM(tsu.user_objects_alloc_page_count + tsu.internal_objects_alloc_page_count) AS writes_in_tempdb
            FROM sys.dm_exec_requests r
            JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
            JOIN sys.dm_db_task_space_usage tsu ON s.session_id = tsu.session_id and r.request_id = tsu.request_id
            WHERE r.status IN ('running', 'runnable', 'suspended')
            GROUP BY
                  r.session_id,
                  s.host_name,
                  s.login_name,
                  r.start_time,
                  r.sql_handle,
                  r.database_id,
                  r.blocking_session_id,
                  r.wait_type,
                  r.status,
                  r.statement_start_offset,
                  r.statement_end_offset,
                  s.program_name,
                  r.percent_complete
      ) x
      where x.session_id <> @@spid
      order by x.totalCPU desc
-- ========================================= finding the SPID of running jobs ==

    --View Blocking in Current Database
    --Author: Timothy Ford
    --http://thesqlagentman.com
    --drop table #blocking
    select dtl.resource_type,
       case
           when dtl.resource_type in ('database', 'file', 'metadata') then dtl.resource_type
           when dtl.resource_type = 'object' then object_name(dtl.resource_associated_entity_id)
           when dtl.resource_type in ('key', 'page', 'rid') then
               (
               select object_name([object_id])
               from sys.partitions
               where sys.partitions.hobt_id =
               dtl.resource_associated_entity_id
               )
           else 'unidentified'
       end as requested_object_name, dtl.request_mode, dtl.request_status,
       dowt.wait_duration_ms, dowt.wait_type, dowt.session_id as [blocked_session_id],
       sp_blocked.[loginame] as [blocked_user],
       convert(nvarchar(max),null) as [blocked_command],
       -- dest_blocked.[text] as [blocked_command],
       dowt.blocking_session_id, sp_blocking.[loginame] as [blocking_user],
       convert(nvarchar(max),null) as [blocking_command],
       -- dest_blocking.[text] as [blocking_command],
       dowt.resource_description,
       sp_blocked.[sql_handle] as sp_blocked_sql_handle,
       sp_blocking.[sql_handle] as sp_blocking_sql_handle
    into #blocking
    -- select *
    from sys.dm_tran_locks as dtl with (nolock)
       inner join sys.dm_os_waiting_tasks as dowt with (nolock)
           on dtl.lock_owner_address = dowt.resource_address
       inner join sys.sysprocesses as sp_blocked with (nolock)
           on dowt.[session_id] = sp_blocked.[spid]
       inner join sys.sysprocesses as sp_blocking with (nolock)
           on dowt.[blocking_session_id] = sp_blocking.[spid]

    update #blocking set
        [blocked_command]=dest_blocked.[text],
        [blocking_command]=dest_blocking.[text]
    from #blocking b
       cross apply sys.[dm_exec_sql_text](sp_blocked_sql_handle) as dest_blocked
       cross apply sys.[dm_exec_sql_text](sp_blocking_sql_handle) as dest_blocking
    -- where dtl.[resource_database_id] = db_id()

    select * from #blocking
    drop table #blocking
    end -- view of n of locks and blocking

-- version check
declare @version  varchar(20)
select  @version = convert(varchar, serverproperty('productversion'))
if @version not like '[0-9][0-9].%'
   select @version = '0' + @version
if @version < '09.00.3042'
    begin
    raiserror('beta_lockinfo requires sql server 2005 sp2 or later', 16, 127)
    goto ret
    end

-- compatibility level check
if (select compatibility_level
    from   sys.databases
    where  name = db_name()) < 90
    begin
    raiserror('you cannot install beta_lockinfo in database with compat.level 80 or lower.', 16, 127)
    goto ret
    end

-- this table holds the information in sys.dm_tran_locks, aggregated
-- on a number of items. note that we do not include subthreads or
-- requests in the aggregation.
declare @locks table (
   session_id      int  not null,
   req_mode        varchar(60)   collate latin1_general_bin2 not null,
   rsc_type        varchar(60)   collate latin1_general_bin2 not null,
   rsc_subtype     varchar(60)   collate latin1_general_bin2 not null,
   req_status      varchar(60)   collate latin1_general_bin2 not null,
   req_owner_type  varchar(60)   collate latin1_general_bin2 not null,
   rsc_description nvarchar(256) collate latin1_general_bin2 null,
   database_id     int      not null,
   entity_id       bigint   null,
   cnt             int      not null,
   activelock as case when rsc_type = 'database' and
                           req_status = 'grant'
                      then convert(bit, 0)
                      else convert(bit, 1)
                 end,
   ident          int identity primary key,
   rowno          int null     -- set per session_id if @procdata is f.
)

-- this table holds the translation of entity_id in @locks. this is a
-- temp table since we access it from dynamic sql. the type_desc is used
-- for allocation units.
create table #objects (
     idtype         char(4)       not null
        check (idtype in ('obj', 'hobt', 'au', 'misc')),
     database_id    int           not null,
     entity_id      bigint        not null,
     hobt_id        bigint        null,
     object_name    nvarchar(550) collate latin1_general_bin2 null,
     type_desc      varchar(60)   collate latin1_general_bin2 null,
     primary key clustered (database_id, idtype, entity_id),
     unique nonclustered (database_id, entity_id, idtype)
)

-- this table captures sys.dm_os_waiting_tasks and later augment it with
-- data about the block chain. a waiting task always has a always has a
-- task address, but the blocker may be idle and without a task.
-- all columns for the blocker are nullable, as we add extra rows for
-- non-waiting blockers.
declare @dm_os_waiting_tasks table
   (wait_session_id   smallint     not null,
    wait_task         varbinary(8) not null,
    block_session_id  smallint     null,
    block_task        varbinary(8) null,
    wait_type         varchar(60) collate latin1_general_bin2  null,
    wait_duration_ms  bigint       null,
    -- the level in the chain. level 0 is the lead blocker. null for
    -- tasks that are waiting, but not blocking.
    block_level       smallint     null,
    -- the lead blocker for this block chain.
    lead_blocker_spid smallint     null,
    -- whether the block chain consists of the threads of the same spid only.
    blocksamespidonly bit         not null default 0,
  unique clustered (wait_session_id, wait_task, block_session_id, block_task),
  unique (block_session_id, block_task, wait_session_id, wait_task)
)

-- this table holds information about transactions tied to a session.
-- a session can have multiple transactions when there are multiple
-- requests, but in that case we only save data about the oldest
-- transaction.
declare @transactions table (
   session_id       smallint      not null,
   is_user_trans    bit           not null,
   trans_start      datetime      not null,
   trans_since      decimal(10,3) null,
   trans_type       int           not null,
   trans_state      int           not null,
   dtc_state        int           not null,
   is_bound         bit           not null,
   primary key (session_id)
)


-- this table holds information about all sessions and requests.
declare @procs table (
   session_id       smallint      not null,
   task_address     varbinary(8)  not null,
   exec_context_id  int           not null,
   request_id       int           not null,
   spidstr as ltrim(str(session_id)) +
              case when exec_context_id <> 0 or request_id <> 0
                   then '/' + ltrim(str(exec_context_id)) +
                        '/' + ltrim(str(request_id))
                   else ''
              end,
   is_user_process  bit           not null,
   orig_login       nvarchar(128) collate latin1_general_bin2 null,
   current_login    nvarchar(128) collate latin1_general_bin2 null,
   session_state    varchar(30)   collate latin1_general_bin2 not null,
   task_state       varchar(60)   collate latin1_general_bin2 null,
   proc_dbid        smallint      null,
   request_dbid     smallint      null,
   host_name        nvarchar(128) collate latin1_general_bin2 null,
   host_process_id  int           null,
   endpoint_id      int           not null,
   program_name     nvarchar(128) collate latin1_general_bin2 null,
   request_command  varchar(32)   collate latin1_general_bin2 null,
   trancount        int           not null,
   session_cpu      int           not null,
   request_cpu      int           null,
   session_physio   bigint        not null,
   request_physio   bigint        null,
   session_logreads bigint        not null,
   request_logreads bigint        null,
   isclr            bit           not null default 0,
   nest_level       int           null,
   now              datetime      not null,
   login_time       datetime      not null,
   last_batch       datetime      not null,
   last_since       decimal(10,3) null,
   curdbid          smallint      null,
   curobjid         int           null,
   current_stmt     nvarchar(max) collate latin1_general_bin2 null,
   sql_handle       varbinary(64) null,
   plan_handle      varbinary(64) null,
   stmt_start       int           null,
   stmt_end         int           null,
   current_plan     xml           null,
   rowno            int           not null,
   block_level      tinyint       null,
   block_session_id smallint      null,
   block_exec_context_id int      null,
   block_request_id      int      null,
   blockercnt        int          null,
   block_spidstr as ltrim(str(block_session_id)) +
               case when block_exec_context_id <> 0 or block_request_id <> 0
                    then '/' + ltrim(str(block_exec_context_id)) +
                         '/' + ltrim(str(block_request_id))
                    else ''
               end +
               case when blockercnt > 1
                    then ' (+' + ltrim(str(blockercnt - 1)) + ')'
                    else ''
               end,
   blocksamespidonly bit          not null default 0,
   waiter_no_blocker bit          not null default 0,
   wait_type        varchar(60)   collate latin1_general_bin2 null,
   wait_time        decimal(18,3) null,
   primary key (session_id, task_address))


-- output from dbcc inputbuffer. the identity column is there to make
-- it possible to add the spid later.
declare @inputbuffer table
       (eventtype    nvarchar(30)   null,
        params       int            null,
        inputbuffer  nvarchar(4000) null,
        ident        int            identity unique,
        spid         int            not null default 0 primary key)

------------------------------------------------------------------------
-- local variables.
------------------------------------------------------------------------
declare @now             datetime,
        @ms              int,
        @spid            smallint,
        @rowc            int,
        @lvl             int,
        @dbname          sysname,
        @dbidstr         varchar(10),
        @stmt            nvarchar(max),
        @request_id      int,
        @handle          varbinary(64),
        @stmt_start      int,
        @stmt_end        int;

------------------------------------------------------------------------
-- set up.
------------------------------------------------------------------------
-- all reads are dirty! the most important reason for this is tempdb.sys.objects.
set transaction isolation level read uncommitted;
set nocount on;

-- processes below @minspid are system processes.
select @now = getdate();

-- validate the @procdata parameter, and set default.
if @procdata is null
   select @procdata = 'f'

if @procdata not in ('a', 'f')
begin
   raiserror('invalid value for @procdata parameter. a and f are permitted', 16, 1)
   return
end

------------------------------------------------------------------------
-- first capture all locks. we aggregate by type, object etc to keep
-- down the volume.
------------------------------------------------------------------------
if @debug = 1
begin
   raiserror ('compiling lock information, time 0 ms.', 0, 1) with nowait
end;

-- we force binary collation, to make the group by operation faster.
with cte as (
   select request_session_id,
          req_mode        = request_mode       collate latin1_general_bin2,
          rsc_type        = resource_type      collate latin1_general_bin2,
          rsc_subtype     = resource_subtype   collate latin1_general_bin2,
          req_status      = request_status     collate latin1_general_bin2,
          req_owner_type  = request_owner_type collate latin1_general_bin2,
          rsc_description =
             case when resource_type = 'application'
                  then nullif(resource_description
                              collate latin1_general_bin2, '')
             end,
          resource_database_id, resource_associated_entity_id
    from  sys.dm_tran_locks)
insert @locks (session_id, req_mode, rsc_type, rsc_subtype, req_status,
               req_owner_type, rsc_description,
               database_id, entity_id, cnt)
   select request_session_id, req_mode, rsc_type, rsc_subtype, req_status,
          req_owner_type, rsc_description,
          resource_database_id, resource_associated_entity_id,
          count(*)
   from   cte
   group  by request_session_id, req_mode, rsc_type, rsc_subtype, req_status,
          req_owner_type, rsc_description,
          resource_database_id, resource_associated_entity_id

-----------------------------------------------------------------------
-- get the blocking chain.
-----------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('determining blocking chain, time %d ms.', 0, 1, @ms) with nowait
end

-- first capture sys.dm_os_waiting_tasks, skipping non-spid tasks. the
-- distinct is needed, because there may be duplicates. (i've seen them.)
insert @dm_os_waiting_tasks (wait_session_id, wait_task, block_session_id,
                             block_task, wait_type, wait_duration_ms)
   select distinct
          owt.session_id, owt.waiting_task_address, owt.blocking_session_id,
          case when owt.blocking_session_id is not null
               then coalesce(owt.blocking_task_address, 0x)
          end, owt.wait_type, owt.wait_duration_ms
   from   sys.dm_os_waiting_tasks owt
   where  owt.session_id is not null;

-----------------------------------------------------------------------
-- get transaction.
-----------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('determining active transactions, time %d ms.', 0, 1, @ms) with nowait
end

; with oldest_tran as (
    select tst.session_id, tst.is_user_transaction,
           tat.transaction_begin_time, tat.transaction_type,
           tat.transaction_state, tat.dtc_state, tst.is_bound,
           rowno = row_number() over (partition by tst.session_id
                                      order by tat.transaction_begin_time asc)
    from   sys.dm_tran_session_transactions tst
    join   sys.dm_tran_active_transactions tat
       on  tst.transaction_id = tat.transaction_id
)
insert @transactions(session_id, is_user_trans, trans_start,
                     trans_since,
                     trans_type, trans_state, dtc_state, is_bound)
   select session_id, is_user_transaction, transaction_begin_time,
          case when datediff(day, transaction_begin_time, @now) > 20
               then null
               else datediff(ms, transaction_begin_time,  @now) / 1000.000
          end,
          transaction_type, transaction_state, dtc_state, is_bound
   from   oldest_tran
   where  rowno = 1

------------------------------------------------------------------------
-- then get the processes. we filter here for active processes once for all
------------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('collecting process information, time %d ms.', 0, 1, @ms) with nowait
end

insert @procs(session_id, task_address,
              exec_context_id, request_id,
              is_user_process,
              current_login,
              orig_login,
              session_state, task_state, endpoint_id, proc_dbid, request_dbid,
              host_name, host_process_id, program_name, request_command,
              trancount,
              session_cpu, request_cpu,
              session_physio, request_physio,
              session_logreads, request_logreads,
              isclr, nest_level,
              now, login_time, last_batch,
              last_since,
              sql_handle, plan_handle,
              stmt_start, stmt_end,
              rowno)
   select es.session_id, coalesce(ot.task_address, 0x),
          coalesce(ot.exec_context_id, 0), coalesce(er.request_id, 0),
          es.is_user_process,
          coalesce(nullif(es.login_name, ''), suser_sname(es.security_id)),
          coalesce(nullif(es.login_name, ''), -- ex original_login_name
                   suser_sname(es.security_id)), -- ex original_security_id
          es.status, ot.task_state, es.endpoint_id, sp.dbid, er.database_id,
          es.host_name, es.host_process_id, es.program_name, er.command,
          coalesce(er.open_transaction_count, sp.open_tran),
          es.cpu_time, er.cpu_time,
          es.reads + es.writes, er.reads + er.writes,
          es.logical_reads, er.logical_reads,
          coalesce(er.executing_managed_code, 0), er.nest_level,
          @now, es.login_time, es.last_request_start_time,
          case when datediff(day, es.last_request_start_time, @now) > 20
               then null
               else datediff(ms, es.last_request_start_time,  @now) / 1000.000
          end,
          er.sql_handle, er.plan_handle,
          er.statement_start_offset, er.statement_end_offset,
          rowno = row_number() over (partition by es.session_id
                                     order by ot.exec_context_id, er.request_id)
   -- select *
   from   sys.dm_exec_sessions es
   join   (select spid, dbid = min(dbid), open_tran = min(open_tran)
           from   sys.sysprocesses
           where  ecid = 0
           group  by spid) as sp on sp.spid = es.session_id
   left   join sys.dm_os_tasks ot on es.session_id = ot.session_id
   left   join sys.dm_exec_requests er on ot.task_address = er.task_address
   where  -- all processes requested
          @allprocesses > 0
          -- all user sessions with a running request save ourselevs.
      or  ot.exec_context_id is not null and
          es.is_user_process = 1  and
          es.session_id <> @@spid
          -- all sessions with an open transaction, even if they are idle.
     or   sp.open_tran > 0 and es.session_id <> @@spid
          -- all sessions that have an interesting lock, save ourselves.
     or   exists (select *
                   from   @locks l
                   where  l.session_id = es.session_id
                     and  l.activelock = 1) and es.session_id <> @@spid
          -- all sessions that is blocking someone.
     or   exists (select *
                  from   @dm_os_waiting_tasks owt
                  where  owt.block_session_id = es.session_id)

------------------------------------------------------------------------
-- get input buffers. note that we can only find one per session, even
-- a session has several requests.
-- we skip this part if @@nestlevel is > 1, as presumably we are calling
-- ourselves recursively from insert exec, and we may no not do another
-- level of insert-exec.
------------------------------------------------------------------------
if @@nestlevel = 1
begin
   if @debug = 1
   begin
      select @ms = datediff(ms, @now, getdate())
      raiserror ('getting input buffers, time %d ms.', 0, 1, @ms) with nowait
   end

   declare c1 cursor fast_forward local for
      select distinct session_id
      from   @procs
      where  is_user_process = 1
   open c1

   while 1 = 1
   begin
      fetch c1 into @spid
      if @@fetch_status <> 0
         break

      begin try
         insert @inputbuffer(eventtype, params, inputbuffer)
            exec sp_executesql N'dbcc inputbuffer (@spid) with no_infomsgs',
                               N'@spid int', @spid

         update @inputbuffer
         set    spid = @spid
         where  ident = scope_identity()
      end try
      begin catch
         insert @inputbuffer(inputbuffer, spid)
            values('error getting inputbuffer: ' + error_message(), @spid)
      end catch
  end

   deallocate c1
end

-----------------------------------------------------------------------
-- compute the blocking chain.
-----------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('computing blocking chain, time %d ms.', 0, 1, @ms) with nowait
end

-- mark blockers that are waiting, that is waiting for something else
-- than another spid.
update @dm_os_waiting_tasks
set    block_level = 0,
       lead_blocker_spid = a.wait_session_id
from   @dm_os_waiting_tasks a
where  a.block_session_id is null
  and  exists (select *
               from   @dm_os_waiting_tasks b
               where  a.wait_session_id = b.block_session_id
                 and  a.wait_task       = b.block_task)
select @rowc = @@rowcount

-- add an extra row for blockers that are not waiting at all.
insert @dm_os_waiting_tasks (wait_session_id, wait_task,
                             block_level, lead_blocker_spid)
   select distinct a.block_session_id, coalesce(a.block_task, 0x),
                   0, a.block_session_id
   from   @dm_os_waiting_tasks a
   where  not exists (select *
                      from  @dm_os_waiting_tasks b
                      where a.block_session_id = b.wait_session_id
                        and a.block_task       = b.wait_task)
     and  a.block_session_id is not null;

select @rowc = @rowc + @@rowcount, @lvl = 0

-- then iterate as long as we find blocked processes. you may think
-- that a recursive cte would be great here, but we want to exclude
-- rows that has already been marked. this is difficult to do with a cte.
while @rowc > 0
begin
   update a
   set    block_level = b.block_level + 1,
          lead_blocker_spid = b.lead_blocker_spid
   from   @dm_os_waiting_tasks a
   join   @dm_os_waiting_tasks b on a.block_session_id = b.wait_session_id
                                and a.block_task       = b.wait_task
   where  b.block_level = @lvl
     and  a.block_level is null

  select @rowc = @@rowcount, @lvl = @lvl + 1
end

-- next to find are processes that are blocked, but no one is waiting for.
-- they are directly or indirectly blocked by a deadlock. they get a
-- negative level initially. we clean this up later.
update @dm_os_waiting_tasks
set    block_level = -1
from   @dm_os_waiting_tasks a
where  a.block_level is null
  and  a.block_session_id is not null
  and  not exists (select *
                   from   @dm_os_waiting_tasks b
                   where  b.block_session_id = a.wait_session_id
                     and  b.block_task       = a.wait_task)

select @rowc = @@rowcount, @lvl = -2

-- then unwind these chains in the opposite direction to before.
while @rowc > 0
begin
   update @dm_os_waiting_tasks
   set    block_level = @lvl
   from   @dm_os_waiting_tasks a
   where  a.block_level is null
     and  a.block_session_id is not null
     and  not exists (select *
                      from   @dm_os_waiting_tasks b
                      where  b.block_session_id = a.wait_session_id
                        and  b.block_task       = a.wait_task
                        and  b.block_level is null)
   select @rowc = @@rowcount, @lvl = @lvl - 1
end

-- determine which blocking tasks that only block tasks within the same
-- spid.
update @dm_os_waiting_tasks
set    blocksamespidonly = 1
from   @dm_os_waiting_tasks a
where  a.block_level is not null
  and  a.wait_session_id = a.lead_blocker_spid
  and  not exists (select *
                   from   @dm_os_waiting_tasks b
                   where  a.wait_session_id = b.lead_blocker_spid
                     and  a.wait_session_id <> b.wait_session_id)

-----------------------------------------------------------------------
-- add block-chain and wait information to @procs. if a blockee has more
-- than one blocker, we pick one.
-----------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('adding blocking chain to @procs, time %d ms.', 0, 1, @ms) with nowait
end

; with block_chain as (
    select wait_session_id, wait_task, block_session_id, block_task,
           block_level = case when block_level >= 0 then block_level
                              else block_level - @lvl - 1
                         end,
    wait_duration_ms, wait_type, blocksamespidonly,
    cnt   = count(*) over (partition by wait_task),
    rowno = row_number() over (partition by wait_task
                               order by block_level, block_task)
    from @dm_os_waiting_tasks
)
update p
set    block_level           = bc.block_level,
       block_session_id      = bc.block_session_id,
       block_exec_context_id = coalesce(p2.exec_context_id, -1),
       block_request_id      = coalesce(p2.request_id, -1),
       blockercnt            = bc.cnt,
       blocksamespidonly     = bc.blocksamespidonly,
       wait_time             = convert(decimal(18, 3), bc.wait_duration_ms) / 1000,
       wait_type             = bc.wait_type
from   @procs p
join   block_chain bc on p.session_id   = bc.wait_session_id
                     and p.task_address = bc.wait_task
                     and bc.rowno = 1
left   join @procs p2 on bc.block_session_id = p2.session_id
                     and bc.block_task       = p2.task_address

--------------------------------------------------------------------
-- delete "uninteresting" locks from @locks for processes not in @procs.
--------------------------------------------------------------------
if @allprocesses = 0
begin
   if @debug = 1
   begin
      select @ms = datediff(ms, @now, getdate())
      raiserror ('deleting uninteresting locks, time %d ms.', 0, 1, @ms) with nowait
   end

   delete @locks
   from   @locks l
   where  (activelock = 0 or session_id = @@spid)
     and  not exists (select *
                      from   @procs p
                      where  p.session_id = l.session_id)
end

-----------------------------------------------------------------------
-- get object names from ids in @procs and @locks. you may think that
-- we could use object_name and its second database parameter, but
-- object_name takes out a sch-s lock (even with read uncommitted) and
-- gets blocked if a object (read temp table) has been created in a transaction.
-----------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('getting object names, time %d ms.', 0, 1, @ms) with nowait
end

-- first get all entity ids into the temp table. we can translate
-- object ids now. and we save the database name as a fallback for
-- those where do not translate more. yes, we save the entity id twice.
insert #objects (idtype, database_id, entity_id, hobt_id)
   select distinct
          case when rsc_type = 'object' then 'obj'
               when rsc_type in ('page', 'key', 'rid', 'hobt') then 'hobt'
               when rsc_type = 'allocation_unit' then 'au'
               else 'misc'
          end,
          database_id, entity_id, entity_id
   from   @locks
   where  rsc_type in ('page', 'key', 'rid', 'hobt', 'allocation_unit',
                       'object')
   union
   select distinct 'obj', curdbid, curobjid, curobjid
   from   @procs
   where  curdbid is not null
     and  curobjid is not null


declare c2 cursor static local for
   select distinct str(database_id),
                   quotename(db_name(database_id))
   from   #objects
   where  idtype in  ('obj', 'hobt', 'au')
   option (keepfixed plan)

open c2

while 1 = 1
begin
   fetch c2 into @dbidstr, @dbname
   if @@fetch_status <> 0
      break

   -- first handle allocation units. they bring us a hobt_id, or we go
   -- directly to the object when the container is a partition_id. we
   -- always get the type_desc. to make the dynamic sql easier to read,
   -- we use some placeholders.
   select @stmt = '
      update #objects
      set    type_desc = au.type_desc,
             hobt_id   = case when au.type in (1, 3)
                              then au.container_id
                         end,
             idtype    = case when au.type in (1, 3)
                              then "hobt"
                              else "au"
                         end,
             object_name = case when au.type = 2 then
                              db_name(@dbidstr) + "." +
                              s.name + "." + o.name +
                              case when p.index_id <= 1
                                   then ""
                                   else "." + i.name
                              end +
                              case when p.partition_number > 1
                                   then "(" +
                                         ltrim(str(p.partition_number)) +
                                        ")"
                                   else ""
                              end
                              when au.type = 0 then
                                 db_name(@dbidstr) + " (dropped table et al)"
                           end
      from   #objects ob
      join   @dbname.sys.allocation_units au on ob.entity_id = au.allocation_unit_id
      -- we should only go all the way from sys.partitions, for type = 3.
      left   join  (@dbname.sys.partitions p
                    join    @dbname.sys.objects o on p.object_id = o.object_id
                    join    @dbname.sys.indexes i on p.object_id = i.object_id
                                                 and p.index_id  = i.index_id
                    join    @dbname.sys.schemas s on o.schema_id = s.schema_id)
         on  au.container_id = p.partition_id
        and  au.type = 2
      where  ob.database_id = @dbidstr
        and  ob.idtype = "au"
      option (keepfixed plan);
   '

   -- now we can translate all hobt_id, including those we got from the
   -- allocation units.
   select @stmt = @stmt + '
      update #objects
      set    object_name = db_name(@dbidstr) + "." + s.name + "." + o.name +
                           case when p.index_id <= 1
                                then ""
                                else "." + i.name
                           end +
                           case when p.partition_number > 1
                                then "(" +
                                      ltrim(str(p.partition_number)) +
                                     ")"
                                else ""
                           end + coalesce(" (" + ob.type_desc + ")", "")
      from   #objects ob
      join   @dbname.sys.partitions p on ob.hobt_id  = p.hobt_id
      join   @dbname.sys.objects o    on p.object_id = o.object_id
      join   @dbname.sys.indexes i    on p.object_id = i.object_id
                                     and p.index_id  = i.index_id
      join   @dbname.sys.schemas s    on o.schema_id = s.schema_id
      where  ob.database_id = @dbidstr
        and  ob.idtype = "hobt"
      option (keepfixed plan)
      '

   -- and now object ids, idtype = obj.
   select @stmt = @stmt + '
      update #objects
      set    object_name = db_name(@dbidstr) + "." +
                           coalesce(s.name + "." + o.name,
                                    "<" + ltrim(str(ob.entity_id)) + ">")
      from   #objects ob
      left   join   (@dbname.sys.objects o
                     join @dbname.sys.schemas s on o.schema_id = s.schema_id)
             on convert(int, ob.entity_id) = o.object_id
      where  ob.database_id = @dbidstr
        and  ob.idtype = "obj"
      option (keepfixed plan)
   '

   -- fix the placeholders.
   select @stmt = replace(replace(replace(@stmt,
                         '"', ''''),
                         '@dbname', @dbname),
                         '@dbidstr', @dbidstr)

   --  and run the beast.
   --print @stmt
   exec (@stmt)
end
deallocate c2

----------------------------------------------------------------------
-- get the query text. this is not done in the main query, as we could
-- be blocked if someone is creating an sp and executes it in a
-- transaction.
----------------------------------------------------------------------
if @@nestlevel = 1
begin
   if @debug = 1
   begin
      select @ms = datediff(ms, @now, getdate())
      raiserror ('retrieving current statement, time %d ms.', 0, 1, @ms) with nowait
   end

   -- set lock timeout to avoid being blocked.
   set lock_timeout 5

   -- first try to get all query plans in one go.
   begin try
      update @procs
      set    curdbid      = est.dbid,
             curobjid     = est.objectid,
             current_stmt =
             case when est.encrypted = 1
                  then '-- encrypted, pos ' +
                       ltrim(str((p.stmt_start + 2)/2)) + ' - ' +
                       ltrim(str((p.stmt_end + 2)/2))
                  when p.stmt_start >= 0
                  then substring(est.text, (p.stmt_start + 2)/2,
                                 case p.stmt_end
                                      when -1 then datalength(est.text)
                                    else (p.stmt_end - p.stmt_start + 2) / 2
                                 end)
             end
      from   @procs p
      cross  apply sys.dm_exec_sql_text(p.sql_handle) est
   end try
   begin catch
      -- if this fails, try to get the texts one by one.
      declare text_cur cursor static local for
         select distinct session_id, request_id, sql_handle,
                         stmt_start, stmt_end
         from   @procs
         where  sql_handle is not null
      open text_cur

      while 1 = 1
      begin
         fetch text_cur into @spid, @request_id, @handle,
                             @stmt_start, @stmt_end
         if @@fetch_status <> 0
            break

         begin try
            update @procs
            set    curdbid      = est.dbid,
                   curobjid     = est.objectid,
                   current_stmt =
                   case when est.encrypted = 1
                        then '-- encrypted, pos ' +
                             ltrim(str((p.stmt_start + 2)/2)) + ' - ' +
                             ltrim(str((p.stmt_end + 2)/2))
                        when p.stmt_start >= 0
                        then substring(est.text, (p.stmt_start + 2)/2,
                                       case p.stmt_end
                                            when -1 then datalength(est.text)
                                          else (p.stmt_end - p.stmt_start + 2) / 2
                                       end)
                   end
            from   @procs p
            cross  apply sys.dm_exec_sql_text(p.sql_handle) est
            where  p.session_id = @spid
              and  p.request_id = @request_id
         end try
         begin catch
             update @procs
             set    current_stmt = 'error: *** ' + error_message() + ' ***'
             where  session_id = @spid
               and  request_id = @request_id
         end catch
      end

      deallocate text_cur

      end catch

   set lock_timeout 0
end


--------------------------------------------------------------------
-- get query plans. the difficult part is that the convert to xml may
-- fail if the plan is too deep. therefore we catch this error, and
-- resort to a cursor in this case. since query plans are not included
-- in text mode, we skip if @nestlevel is > 1.
--------------------------------------------------------------------
if @@nestlevel = 1
begin
   if @debug = 1
   begin
      select @ms = datediff(ms, @now, getdate())
      raiserror ('retrieving query plans, time %d ms.', 0, 1, @ms) with nowait
   end

   -- adam says that getting the query plans can time out too...
   set lock_timeout 5

   begin try
      update @procs
      set    current_plan = convert(xml, etqp.query_plan)
      from   @procs p
      outer  apply sys.dm_exec_text_query_plan(
                   p.plan_handle, p.stmt_start, p.stmt_end) etqp
      where  p.plan_handle is not null
   end try
   begin catch
      declare plan_cur cursor static local for
         select distinct session_id, request_id, plan_handle,
                         stmt_start, stmt_end
         from   @procs
         where  plan_handle is not null
      open plan_cur

      while 1 = 1
      begin
         fetch plan_cur into @spid, @request_id, @handle,
                             @stmt_start, @stmt_end
         if @@fetch_status <> 0
            break

         begin try
            update @procs
            set    current_plan = (select convert(xml, etqp.query_plan)
                                   from   sys.dm_exec_text_query_plan(
                                      @handle, @stmt_start, @stmt_end) etqp)
            from   @procs p
            where  p.session_id = @spid
              and  p.request_id = @request_id
         end try
         begin catch
            update @procs
            set    current_plan =
                     (select 'could not get query plan' as [@alert],
                             error_number() as [@errno],
                             error_severity() as [@level],
                             error_message() as [@errmsg]
                      for    xml path('error'))
            where  session_id = @spid
              and  request_id = @request_id
         end catch
      end

      deallocate plan_cur
   end catch

   set lock_timeout 0

   -- there is a bug in dm_exec_text_query_plan which causes the attribute
   -- statementtext to include the full text of the batch up to current
   -- statement. this causes bloat in ssms. whence we fix the attribute.
   ; with xmlnamespaces(
      'http://schemas.microsoft.com/sqlserver/2004/07/showplan' as sp)
   update @procs
   set    current_plan.modify('
            replace value of (
                  /sp:showplanxml/sp:batchsequence/sp:batch/
                   sp:statements/sp:stmtsimple/@statementtext)[1]
            with
               substring((/sp:showplanxml/sp:batchsequence/sp:batch/
                         sp:statements/sp:stmtsimple/@statementtext)[1],
                        (sql:column("stmt_start") + 2) div 2)
          ')
   where  current_plan is not null
     and  stmt_start is not null
end

--------------------------------------------------------------------
-- if user has selected to see process data only on the first row,
-- we should number the rows in @locks.
--------------------------------------------------------------------
if @procdata = 'f'
begin
   if @debug = 1
   begin
      select @ms = datediff(ms, @now, getdate())
      raiserror ('determining first row, time %d ms.', 0, 1, @ms) with nowait
   end

   update @locks
   set    rowno = b.rowno
   from   @locks a
   join   (select l.ident,
                  rowno = row_number() over(partition by l.session_id
                    order by case l.req_status
                                  when 'grant' then 'zzzz'
                                  else l.req_status
                             end, o.object_name, l.rsc_type, l.rsc_description)
           from   @locks l
           left   join   #objects o on l.database_id = o.database_id
                                   and l.entity_id   = o.entity_id) as b
          on a.ident = b.ident
  option (keepfixed plan)
end

---------------------------------------------------------------------
-- before we can join in the locks, we need to make sure that all
-- processes with a running request has a row with exec_context_id =
-- request_id = 0. (those without already has such a row.)
---------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('supplementing @procs, time %d ms.', 0, 1, @ms) with nowait
end

insert @procs(session_id, task_address, exec_context_id, request_id,
              is_user_process, orig_login, current_login,
              session_state, endpoint_id, trancount, proc_dbid,
              host_name, host_process_id, program_name,
              session_cpu, session_physio, session_logreads,
              now, login_time, last_batch, last_since, rowno)
   select session_id, 0x, 0, 0,
          is_user_process, orig_login, current_login,
          session_state, endpoint_id, 0, proc_dbid,
          host_name, host_process_id, program_name,
          session_cpu, session_physio, session_logreads,
          now, login_time, last_batch, last_since, 0
    from  @procs a
    where a.rowno = 1
      and not exists (select *
                      from   @procs b
                      where  b.session_id      = a.session_id
                        and  b.exec_context_id = 0
                        and  b.request_id      = 0)

-- a process may be waiting for a lock according sys.dm_os_tran_locks,
-- but it was not in sys.dm_os_waiting_tasks. let's mark this up.
update @procs
set    waiter_no_blocker = 1
from   @procs p
where  exists (select *
               from   @locks l
               where  l.req_status = 'wait'
                 and  l.session_id = p.session_id
                 and  not exists (select *
                                  from   @procs p2
                                  where  p.session_id = l.session_id))

------------------------------------------------------------------------
-- for plain results we are ready to return now.
------------------------------------------------------------------------
if @debug = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('returning result set, time %d ms.', 0, 1, @ms) with nowait
end

-- note that the query is a full join, since @locks and @procs may not
-- be in sync. processes may have gone away, or be active without any
-- locks. as for the transactions, we team up with the processes.
select
      readed_at   = getdate(),
      spid        = coalesce(p.spidstr, ltrim(str(l.session_id))),
      command     = case when coalesce(p.exec_context_id, 0) = 0 and
                              coalesce(l.rowno, 1) = 1
                         then p.request_command
                         else ''
                    end,
      login       = case when coalesce(p.exec_context_id, 0) = 0 and
                              coalesce(l.rowno, 1) = 1
                         then
                         case when p.is_user_process = 0
                              then 'system process'
                              else p.orig_login +
                                 case when p.current_login <> p.orig_login or
                                           p.orig_login is null
                                      then ' (' + p.current_login + ')'
                                      else ''
                                 end
                        end
                        else ''
                    end,
      host        = case when coalesce(p.exec_context_id, 0)= 0 and
                              coalesce(l.rowno, 1) = 1
                         then p.host_name
                         else ''
                    end,
      appl        = case when coalesce(p.exec_context_id, 0) = 0 and
                              coalesce(l.rowno, 1) = 1
                         then p.program_name
                         else ''
                    end,
      dbname      = case when coalesce(l.rowno, 1) = 1 and
                              coalesce(p.exec_context_id, 0) = 0
                         then coalesce(db_name(p.request_dbid),
                                       db_name(p.proc_dbid))
                         else ''
                    end,
      prcstatus   = case when coalesce(l.rowno, 1) = 1
                         then coalesce(p.task_state, p.session_state)
                         else ''
                    end,
      spid_       = p.spidstr,
      opntrn      = case when p.exec_context_id = 0
                         then coalesce(ltrim(str(nullif(p.trancount, 0))), '')
                         else ''
                    end,
      trninfo     = case when coalesce(l.rowno, 1) = 1 and
                              p.exec_context_id = 0 and
                              t.is_user_trans is not null
                         then case t.is_user_trans
                                   when 1 then 'u'
                                   else 's'
                              end + '-' +
                              case t.trans_type
                                   when 1 then 'rw'
                                   when 2 then 'r'
                                   when 3 then 'sys'
                                   when 4 then 'dist'
                                   else ltrim(str(t.trans_type))
                              end + '-' +
                              ltrim(str(t.trans_state)) +
                              case t.dtc_state
                                   when 0 then ''
                                   else '-'
                              end +
                              case t.dtc_state
                                 when 0 then ''
                                 when 1 then 'dtc:active'
                                 when 2 then 'dtc:prepared'
                                 when 3 then 'dtc:commited'
                                 when 4 then 'dtc:aborted'
                                 when 5 then 'dtc:recovered'
                                 else 'dtc:' + ltrim(str(t.dtc_state))
                             end +
                             case t.is_bound
                                when 0 then ''
                                when 1 then '-bnd'
                             end
                        else ''
                    end,
      blklvl      = case when p.block_level is not null
                         then case p.blocksamespidonly
                                   when 1 then '('
                                   else ''
                              end +
                              case when p.block_level = 0
                                   then '!!'
                                   else ltrim(str(p.block_level))
                              end +
                              case p.blocksamespidonly
                                   when 1 then ')'
                                   else ''
                              end
                         -- if the process is blocked, but we do not
                         -- have a block level, the process is in a
                         -- dead lock.
                         when p.block_session_id is not null
                         then 'dd'
                         when p.waiter_no_blocker = 1
                         then '??'
                         else ''
                    end,
      blkby       = coalesce(p.block_spidstr, ''),
      cnt         = case when p.exec_context_id = 0 and
                              p.request_id = 0
                         then coalesce(ltrim(str(l.cnt)), '0')
                         else ''
                    end,
      object      = case l.rsc_type
                       when 'application'
                       then coalesce(db_name(l.database_id) + '|', '') +
                                     l.rsc_description
                       else coalesce(o2.object_name,
                                     db_name(l.database_id), '')
                    end,
      rsctype     = coalesce(l.rsc_type, ''),
      locktype    = coalesce(l.req_mode, ''),
      lstatus     = case l.req_status
                         when 'grant' then lower(l.req_status)
                         else coalesce(l.req_status, '')
                    end,
      ownertype   = case l.req_owner_type
                         when 'shared_transaction_workspace' then 'stw'
                         else coalesce(l.req_owner_type, '')
                    end,
      rscsubtype  = coalesce(l.rsc_subtype, ''),
      waittime    = case when coalesce(l.rowno, 1) = 1
                         then coalesce(ltrim(str(p.wait_time, 18, 3)), '')
                         else ''
                    end,
      waittype    = case when coalesce(l.rowno, 1) = 1
                         then coalesce(p.wait_type, '')
                         else ''
                    end,
      spid__      = p.spidstr,
      cpu         = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then coalesce(ltrim(str(p.session_cpu)), '') +
                         case when p.request_cpu is not null
                              then ' (' + ltrim(str(p.request_cpu)) + ')'
                              else ''
                         end
                         else ''
                    end,
      physio      = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then coalesce(ltrim(str(p.session_physio, 18)), '') +
                         case when p.request_physio is not null
                              then ' (' + ltrim(str(p.request_physio)) + ')'
                              else ''
                         end
                         else ''
                    end,
      logreads    = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then coalesce(ltrim(str(p.session_logreads, 18)), '')  +
                         case when p.request_logreads is not null
                              then ' (' + ltrim(str(p.request_logreads)) + ')'
                              else ''
                         end
                         else ''
                    end,
      now         = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then convert(char(12), p.now, 114)
                         else ''
                    end,
      login_time  = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then
                         case datediff(day, p.login_time, @now)
                              when 0
                              then convert(varchar(8), p.login_time, 8)
                              else convert(char(7), p.login_time, 12) +
                                   convert(varchar(8), p.login_time, 8)
                         end
                         else ''
                    end,
      last_batch  = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then
                         case datediff(day, p.last_batch, @now)
                              when 0
                              then convert(varchar(8),
                                           p.last_batch, 8)
                              else convert(char(7), p.last_batch, 12) +
                                   convert(varchar(8), p.last_batch, 8)
                         end
                         else ''
                    end,
      trn_start   = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1 and
                              t.trans_start is not null
                         then
                         case datediff(day, t.trans_start, @now)
                              when 0
                              then convert(varchar(8),
                                           t.trans_start, 8)
                              else convert(char(7), t.trans_start, 12) +
                                   convert(varchar(8), t.trans_start, 8)
                         end
                         else ''
                    end,
      last_since  = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then str(p.last_since, 11, 3)
                         else ''
                    end,
      trn_since   = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1 and
                              t.trans_since is not null
                         then str(t.trans_since, 11, 3)
                         else ''
                    end,
      clr         = case when p.exec_context_id = 0 and p.isclr = 1
                         then 'clr'
                         else ''
                    end,
      nstlvl      = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then coalesce(ltrim(str(p.nest_level)), '')
                         else ''
                    end,
      spid___     = p.spidstr,
      inputbuffer = case when p.exec_context_id = 0 and
                              coalesce(l.rowno, 1) = 1
                         then coalesce(i.inputbuffer, '')
                         else ''
                    end,
      current_sp  = coalesce(o1.object_name, ''),
      curstmt     = case when coalesce(l.rowno, 1) = 1
                         then coalesce(p.current_stmt, '')
                         else coalesce(substring(
                                    p.current_stmt, 1, 50), '')
                    end,
      current_plan = case when p.exec_context_id = 0 and
                               coalesce(l.rowno, 1) = 1
                          then p.current_plan
                     end,
      hostprc     = case when coalesce(p.exec_context_id, 0) = 0 and
                              coalesce(l.rowno, 1) = 1
                         then ltrim(str(p.host_process_id))
                         else ''
                    end,
      endpoint    = case when coalesce(p.exec_context_id, 0) = 0 and
                              coalesce(l.rowno, 1) = 1
                         then e.name
                         else ''
                    end
from   @procs p
left   join #objects o1 on p.curdbid  = o1.database_id
                      and p.curobjid = o1.entity_id
left   join @inputbuffer i on p.session_id = i.spid
                         and p.exec_context_id = 0
left   join sys.endpoints e on p.endpoint_id = e.endpoint_id
left   join @transactions t on t.session_id = p.session_id
full   join (@locks l
           left join #objects o2 on l.database_id = o2.database_id
                                and l.entity_id   = o2.entity_id)
 on    p.session_id      = l.session_id
and    p.exec_context_id = 0
and    p.request_id      = 0
where  db_name() =  case when coalesce(l.rowno, 1) = 1 and
                              coalesce(p.exec_context_id, 0) = 0
                         then coalesce(db_name(p.request_dbid),
                                       db_name(p.proc_dbid))
                         else ''
                    end
order by
        coalesce(p.session_id, l.session_id),
        p.exec_context_id, coalesce(nullif(p.request_id, 0), 99999999),
        l.rowno, lstatus,
        coalesce(o2.object_name, db_name(l.database_id)),
        l.rsc_type, l.rsc_description
option (keepfixed plan)

if @debug = 1 and @@nestlevel = 1
begin
   select @ms = datediff(ms, @now, getdate())
   raiserror ('completed, time %d ms.', 0, 1, @ms) with nowait
end

if object_id('sp__lock_help') is null
    exec sp__printf '-- missing "sp__lock_help"'
else
    exec sp__lock_help
goto ret

ret:
return @ret
end -- sp__lock_ex