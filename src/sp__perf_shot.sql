/*  leave this
    l:see LICENSE file
    g:utility
    k:performance, snapshot,
    r:130228\s.zaglio: take a snapshot of system for performance evaluation
    t:sp__perf_shot run
*/
CREATE proc sp__perf_shot
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp

set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end
    -- @param=nullif(@param,''),

-- ============================================================== declaration ==
declare
    -- generic common
    @run bit,
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
        |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if  @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- show if phisical disk is involved in I/O bottleneck(?)
-- heavy i/o
select
    db_name(t1.database_id) db,
    file_name(t1.file_id) fname,
    t1.io_stall,
    t2.io_pending_ms_ticks,
    object_name(sql.objectid) obj,
    case when sql_handle is null then ' '
    else ( substring(sql.text,(er.statement_start_offset+2)/2,(case when er.statement_end_offset = -1 then
    len(convert(nvarchar(max),sql.text))*2 else er.statement_end_offset end - er.statement_start_offset) /2 ) )
    end as stm,
    text as sql
from sys.dm_io_virtual_file_stats(NULL, NULL)t1
join sys.dm_io_pending_io_requests as t2  on t1.file_handle = t2.io_handle
left join sys.dm_os_schedulers os on t2.scheduler_address=os.scheduler_address
left join sys.dm_os_workers ow on os.active_worker_address=ow.worker_address
left join sys.dm_exec_requests er on er.task_address=ow.task_address
cross apply sys.dm_exec_sql_text(er.sql_handle) as sql
where io_pending_ms_ticks>20

-- batch that generate most i/o in general
select top 10
    (total_logical_reads/execution_count) as avg_logical_reads,
    (total_logical_writes/execution_count) as avg_logical_writes,
    (total_physical_reads/execution_count) as avg_phys_reads,
     Execution_count,
    statement_start_offset as stmt_start_offset,
    --sql_handle,
    --plan_handle,
    st.text,
    object_name(st.objectid) obj,
    case when sql_handle is null then ' '
    else ( substring(st.text,(qs.statement_start_offset+2)/2,(case when qs.statement_end_offset = -1 then
    len(convert(nvarchar(max),st.text))*2 else qs.statement_end_offset end - qs.statement_start_offset) /2 ) )
    end as stm
from sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text( sql_handle) st
order by
 (total_logical_reads + total_logical_writes) Desc -- in general

-- batch that generate most i/o in single execution
select top 10
    (total_logical_reads/execution_count) as avg_logical_reads,
    (total_logical_writes/execution_count) as avg_logical_writes,
    (total_physical_reads/execution_count) as avg_phys_reads,
     Execution_count,
    -- statement_start_offset as stmt_start_offset,
    --sql_handle,
    --plan_handle,
    object_name(st.objectid) obj,
    case when sql_handle is null then ' '
    else ( substring(st.text,(qs.statement_start_offset+2)/2,(case when qs.statement_end_offset = -1 then
    len(convert(nvarchar(max),st.text))*2 else qs.statement_end_offset end - qs.statement_start_offset) /2 ) )
    end as stm,
    st.text
from sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text( sql_handle) st
order by
 (total_logical_reads + total_logical_writes)/execution_count

-- the following query shows the top 50 sql statements with high average cpu consumption.
select top 10
total_worker_time/execution_count as [avg cpu time],
object_name(objectid) obj,
substring(text,statement_start_offset/2,(case when statement_end_offset = -1 then len(convert(nvarchar(max), text)) * 2 else statement_end_offset end -statement_start_offset)/2) as sql
from sys.dm_exec_query_stats
cross apply sys.dm_exec_sql_text(sql_handle)
order by [avg cpu time] desc

-- How to determine whether any active requests are running in parallel for a given session
Select
    object_name(sql.objectid) obj,
    substring(text,statement_start_offset/2,(case when statement_end_offset = -1 then len(convert(nvarchar(max), text)) * 2 else statement_end_offset end -statement_start_offset)/2) as sql,
    r.session_id, r.request_id, max(isnull(exec_context_id, 0)) as number_of_workers,
    r.sql_handle,r.statement_start_offset,r.statement_end_offset, r.plan_handle
from sys.dm_exec_requests r
join sys.dm_os_tasks t on r.session_id = t.session_id
join sys.dm_exec_sessions s on r.session_id = s.session_id
cross apply sys.dm_exec_sql_text(sql_handle) as sql
where s.is_user_process = 0x1
group by r.session_id, r.request_id, r.sql_handle, r.plan_handle,
r.statement_start_offset, r.statement_end_offset,sql.objectid,sql.text
having max(isnull(exec_context_id, 0)) > 0

-- 6. How to find the total number of worker threads in the runnable state (Waiting for CPU)?
select count(*) as workers_waiting_for_cpu, s.scheduler_id
from sys.dm_os_workers as o inner join sys.dm_os_schedulers as s
on o.scheduler_address = s.scheduler_address and s.scheduler_id < 255
where o.state = 'runnable' group by s.scheduler_id

-- 7. query gives you the top 25 stored procedures that have been recompiled. The plan_generation_num indicates the number of times the query has recompiled.
select top 25
      db_name(dbid) db,
      object_name(sql_text.objectid) obj,
      sql_text.text,
      -- sql_handle,
      sum(plan_generation_num) as plan_generation_num,
      sum(execution_count) execution_count
from sys.dm_exec_query_stats a
cross apply sys.dm_exec_sql_text(sql_handle) as sql_text
where plan_generation_num > 1
group by dbid,sql_text.objectid,sql_text.text
order by plan_generation_num desc

-- 8. How to find the all sessions on SQL Server 2005?
select s.session_id , s.login_time , s.host_name, s.program_name, s.cpu_time / 1000.0 as cpu_time, s.memory_usage*8 as memory_usage
, s.login_name, s.nt_domain, s.nt_user_name, c.connect_time, c.num_reads, c.num_writes, c.client_net_address
, c.client_tcp_port, c.session_id
, case when r.sql_handle is not null then (select top 1 SUBSTRING(t2.text, (r.statement_start_offset + 2) / 2, ( (case when
r.statement_end_offset = -1 then ((len(convert(nvarchar(MAX),t2.text))) * 2) else r.statement_end_offset end) - r.statement_start_offset) /
2) from sys.dm_exec_sql_text(r.sql_handle) t2 )
else ''
end as sql_statement
from sys.dm_exec_sessions s
left outer join sys.dm_exec_connections c on ( s.session_id = c.session_id )
left outer join sys.dm_exec_requests r on ( r.session_id = c.session_id and r.connection_id = c.connection_id )
where s.is_user_process = 1

-- How to find the TEMP DB space availability?
select sum (user_object_reserved_page_count)*8 as user_objects_kb,
sum (internal_object_reserved_page_count)*8 as internal_objects_kb,
sum (version_store_reserved_page_count)*8 as version_store_kb,
sum (unallocated_extent_page_count)*8 as freespace_kb
-- select *
from sys.dm_db_file_space_usage
where database_id = 2

-- 12. How to list the Queries by total IO?
select top 10 rank() over (order by total_logical_reads+total_logical_writes desc,sql_handle,statement_start_offset ) as row_no
, creation_time, last_execution_time, (total_worker_time+0.0)/1000 as total_worker_time
, (total_worker_time+0.0)/(execution_count*1000) as [AvgCPUTime]
, total_logical_reads as [LogicalReads], total_logical_writes as [LogicalWrites]
, execution_count, total_logical_reads+total_logical_writes as [AggIO]
, (total_logical_reads+total_logical_writes)/(execution_count+0.0) as [AvgIO]
, case when sql_handle IS NULL then ' '
else ( substring(st.text,(qs.statement_start_offset+2)/2,(case when qs.statement_end_offset = -1 then
len(convert(nvarchar(MAX),st.text))*2 else qs.statement_end_offset end - qs.statement_start_offset) /2 ) )
end as query_text
, db_name(st.dbid) as database_name
, st.objectid as object_id
, object_name(st.objectid) obj
from sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text(sql_handle) st
where total_logical_reads+total_logical_writes > 0
order by [AggIO] desc

-- 11. How to list the queries by Total CPU Time?
select rank() over(order by total_worker_time desc,sql_handle,statement_start_offset) as row_no
, creation_time, last_execution_time, (total_worker_time+0.0)/1000 as total_worker_time
, (total_worker_time+0.0)/(execution_count*1000) as [AvgCPUTime]
, total_logical_reads as [LogicalReads], total_logical_writes as [logicalWrites]
, execution_count, total_logical_reads+total_logical_writes as [AggIO]
, (total_logical_reads+total_logical_writes)/(execution_count + 0.0) as [AvgIO]
, case when sql_handle IS NULL
then ' '
else ( substring(st.text,(qs.statement_start_offset+2)/2,(case when qs.statement_end_offset = -1 then
len(convert(nvarchar(MAX),st.text))*2 else qs.statement_end_offset end - qs.statement_start_offset) /2 ) )
end as query_text
, db_name(st.dbid) as database_name
, st.objectid as object_id
, object_name(st.objectid) obj
from sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text(sql_handle) st
where total_worker_time > 0
order by total_worker_time desc

-- show wait types
select top 10 *
from sys.dm_os_wait_stats
--where wait_type not in ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK','SLEEP_SYSTEMTASK','WAITFOR')
order by wait_time_ms desc

begin try
declare @tab_tran_locks as table(
l_resource_type nvarchar(60) collate database_default
, l_resource_subtype nvarchar(60) collate database_default
, l_resource_associated_entity_id bigint
, l_blocking_request_spid int, l_blocked_request_spid int, l_blocking_request_mode nvarchar(60) collate database_default
, l_blocked_request_mode nvarchar(60) collate database_default, l_blocking_tran_id bigint, l_blocked_tran_id bigint
);
declare @tab_blocked_tran as table (
tran_id bigint
, no_blocked bigint
);
declare @temp_tab table(
blocking_status int, no_blocked int, l_resource_type nvarchar(60) collate database_default
, l_resource_subtype nvarchar(60) collate database_default , l_resource_associated_entity_id bigint
, l_blocking_request_spid int, l_blocked_request_spid int, l_blocking_request_mode nvarchar(60) collate database_default
, l_blocked_request_mode nvarchar(60) collate database_default , l_blocking_tran_id int, l_blocked_tran_id int
, local1 int, local2 int, b_tran_id bigint, w_tran_id bigint, b_name nvarchar(128) collate database_default
, w_name nvarchar(128) collate database_default , b_tran_begin_time datetime, w_tran_begin_time datetime
, b_state nvarchar(60) collate database_default , w_state nvarchar(60) collate database_default
, b_trans_type nvarchar(60) collate database_default , w_trans_type nvarchar(60) collate database_default
, b_text nvarchar(max) collate database_default , w_text nvarchar(max) collate database_default
, db_span_count1 int, db_span_count2 int
);

insert into @tab_tran_locks
select a.resource_type, a.resource_subtype, a.resource_associated_entity_id, a.request_session_id as blocking
, b.request_session_id as blocked, a.request_mode, b.request_mode , a.request_owner_id
, b.request_owner_id
from sys.dm_tran_locks a join sys.dm_tran_locks b on (a.resource_type = b.resource_type and a.resource_subtype = b.resource_subtype and
a.resource_associated_entity_id = b.resource_associated_entity_id and a.resource_description = b.resource_description)
where a.request_status = 'GRANT' and (b.request_status = 'WAIT' or b.request_status = 'CONVERT') and a.request_owner_type = 'TRANSACTION'
and b.request_owner_type = 'TRANSACTION'

insert into @tab_blocked_tran
select ttl.l_blocking_tran_id, count(distinct ttl.l_blocked_tran_id)
from @tab_tran_locks ttl
group by ttl.l_blocking_tran_id
order by count( distinct ttl.l_blocked_tran_id) desc

insert into @temp_tab
select 0 as blocking_status, tbt.no_blocked, ttl.*, st1.is_local as local1, st2.is_local as local2
, st1.transaction_id as b_tran_id, st2.transaction_id as w_tran_id, at1.name as b_name,at2.name as w_name
, at1.transaction_begin_time as b_tran_begin_time, at2.transaction_begin_time as w_tran_begin_time
, case when at1.transaction_type <> 4 then case at1.transaction_state
when 0 then 'Invalid' when 1 then 'Initialized'
when 2 then 'Active' when 3 then 'Ended'
when 4 then 'Commit Started' when 5 then 'Prepared'
when 6 then 'Committed' when 7 then 'Rolling Back'
when 8 then 'Rolled Back'
end
else case at1.dtc_state
when 1 then 'Active' when 2 then 'Prepared'
when 3 then 'Committed' when 4 then 'Aborted'
when 5 then 'Recovered'
end end b_state
, case when at2.transaction_type <> 4 then case at2.transaction_state
when 0 then 'Invalid' when 1 then 'Initialized'
when 2 then 'Active' when 3 then 'Ended'
when 4 then 'Commit Started' when 5 then 'Prepared'
when 6 then 'Committed' when 7 then 'Rolling Back'
when 8 then 'Rolled Back' end
else case at2.dtc_state
when 1 then 'Active' when 2 then 'Prepared'
when 3 then 'Committed' when 4 then 'Aborted'
when 5 then 'Recovered' end
end w_state, at1.transaction_type as b_trans_type
, at2.transaction_type as w_trans_type, case when r1.sql_handle IS NULL then '--' else ( select top 1 substring(text,(r1.statement_start_offset+2)/2, (case when r1.statement_end_offset = -1 then len(convert(nvarchar(MAX),text))*2 else r1.statement_end_offset end - r1.statement_start_offset) /2 )
from sys.dm_exec_sql_text(r1.sql_handle)) end as b_text, case when r2.sql_handle IS NULL then '--' else ( select top 1 substring(text,(r2.statement_start_offset+2)/2, (case when r2.statement_end_offset = -1 then len(convert(nvarchar(MAX),text))*2 else r2.statement_end_offset end - r2.statement_start_offset) /2 ) from sys.dm_exec_sql_text(r2.sql_handle)) end as w_text
, ( Select count(distinct database_id) from sys.dm_tran_database_transactions where transaction_id = st1.transaction_id ) as
db_span_count1, ( Select count(distinct database_id) from sys.dm_tran_database_transactions where transaction_id = st2.transaction_id ) as
db_span_count2
from @tab_tran_locks ttl
inner join sys.dm_tran_active_transactions at1 on(at1.transaction_id = ttl.l_blocking_tran_id)
inner join @tab_blocked_tran tbt on(tbt.tran_id = at1.transaction_id)
inner join sys.dm_tran_session_transactions st1 on(at1.transaction_id = st1.transaction_id)
left outer join sys.dm_exec_requests r1 on(at1.transaction_id = r1.transaction_id )
inner join sys.dm_tran_active_transactions at2 on(at2.transaction_id = ttl.l_blocked_tran_id)
inner join sys.dm_tran_session_transactions st2 on(at2.transaction_id = st2.transaction_id)
left outer join sys.dm_exec_requests r2 on(at2.transaction_id = r2.transaction_id )
where st1.is_user_transaction = 1 and st2.is_user_transaction = 1 order by tbt.no_blocked desc;

with Blocking( blocking_status, no_blocked, total_blocked, l_resource_type, l_resource_subtype
, l_resource_associated_entity_id, l_blocking_request_spid, l_blocked_request_spid, l_blocking_request_mode
, l_blocked_request_mode, local1, local2, b_tran_id, w_tran_id, b_name, w_name, b_tran_begin_time
, w_tran_begin_time, b_state, w_state, b_trans_type, w_trans_type, b_text, w_text, db_span_count1
, db_span_count2, lvl)
as( select blocking_status
, no_blocked , no_blocked , l_resource_type , l_resource_subtype , l_resource_associated_entity_id
, l_blocking_request_spid , l_blocked_request_spid , l_blocking_request_mode , l_blocked_request_mode
, local1 , local2 , b_tran_id , w_tran_id , b_name , w_name , b_tran_begin_time
, w_tran_begin_time , b_state , w_state , b_trans_type , w_trans_type , b_text
, w_text , db_span_count1 , db_span_count2 , 0 from @temp_tab
union all select E.blocking_status
, M.no_blocked , convert(int,E.no_blocked + total_blocked) , E.l_resource_type
, E.l_resource_subtype , E.l_resource_associated_entity_id , M.l_blocking_request_spid
, E.l_blocked_request_spid , M.l_blocking_request_mode , E.l_blocked_request_mode
, M.local1 , E.local2 , M.b_tran_id , E.w_tran_id , M.b_name , E.w_name
, M.b_tran_begin_time , E.w_tran_begin_time , M.b_state , E.w_state , M.b_trans_type
, E.w_trans_type , M.b_text , E.w_text , M.db_span_count1 , E.db_span_count2
, M.lvl+1
from @temp_tab as E
join Blocking as M on E.b_tran_id = M.w_tran_id
)

select *
from Blocking
order by no_blocked desc,b_tran_id,w_tran_id ;
end try
begin catch
select
ERROR_SEVERITY() as blocking_status
, ERROR_STATE() as no_blocked
, ERROR_MESSAGE() as total_blocked
, 1 as l_resource_type,1 as l_resource_subtype,1 as l_resource_associated_entity_id,1 as l_blocking_request_spid,1 as
l_blocked_request_spid,1 as l_blocking_request_mode,1 as l_blocked_request_mode,1 as local1,1 as local2,1 as b_tran_id,1 as w_tran_id,1 as
b_name,1 as w_name,1 as b_tran_begin_time,1 as w_tran_begin_time,1 as b_state,1 as w_state,1 as b_trans_type,1 as w_trans_type,1 as b_text,1
as w_text,1 as db_span_count1,1 as db_span_count2,1 as lvl
end catch

goto dispose

-- shows some operators that may be CPU intensive, such as ‘%Hash Match%’, ‘%Sort%’ to look for suspects.
select object_name(objectid) obj,*
from
      sys.dm_exec_cached_plans
      cross apply sys.dm_exec_query_plan(plan_handle)
where
      cast(query_plan as nvarchar(max)) like '%Sort%'
      or cast(query_plan as nvarchar(max)) like '%Hash Match%'


-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    take a snapshot of system to do some evaluation about performance

Parameters
    @opt    options
            run     execute

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__perf_shot