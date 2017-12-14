/*  leave this
    l:see LICENSE file
    g:utility,nomssql2k
    d:130630\s.zaglio: sp__util_sqltrace
    v:130630\s.zaglio: renamed and small refactor
    v:100810\s.zaglio: originally from http://www.sommarskog.se/index.html
    t:
        exec sp__profile_sql '
            exec sp__printf ''test''
            select top 1000 * from sysobjects
            '
*/
CREATE  procedure sp__profile_sql
  @batch nvarchar(max) = null,      -- sql batch to analyse
  @minreads bigint = 1,             -- min reads (logical)
  @mincpu int = 0,                  -- min cpu time (milliseconds)
  @minduration bigint = 0,          -- min duration (microseconds)
  @factor varchar(50) = 'duration', -- % (duration, reads, writes, cpu)
  @order varchar(50) = '',          -- order (duration, reads, writes, cpu)
  @plans varchar(50) = '',          -- include query plans - intentive (actual, estimated)
  @rollback bit = 0,                -- run in a transaction and rollback
  @timeout int = 300                -- set a maximum trace duration (seconds)
as
begin
set nocount on;
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

if @batch is null goto help

declare
    @id int, @spid int, @file nvarchar(256), @fsize bigint, @plan int, @on bit, @rc int,
    @stoptime datetime, @total int, @rccpu int, @rcduration int

select
    @spid = @@spid, @on = 1, @fsize = 5,
    @plan = case lower(@plans) when 'actual' then 146 when 'estimated' then 122 end,
    @stoptime = dateadd(second, @timeout, getdate())

exec sp__get_temp_dir @file out
select @file = @file+'\'+cast(newid() as char(36))

exec sp_trace_create @id output, 2, @file, @fsize, @stoptime

if @plan is not null begin
    exec sp_trace_setevent @id, @plan, 1, @on   -- xml plan
    exec sp_trace_setevent @id, @plan, 5, @on   -- xml plan / line
    exec sp_trace_setevent @id, @plan, 34, @on   -- xml plan / objectname
    exec sp_trace_setevent @id, @plan, 51, @on   -- xml plan / eventsequence
end
exec sp_trace_setevent @id, 45, 51, @on   -- sp:stmtcompleted / eventseq
exec sp_trace_setevent @id, 41, 51, @on   -- sql:stmtcompleted / eventseq
exec sp_trace_setevent @id, 166, 51, @on   -- sql:stmtrecompile / eventseq
exec sp_trace_setevent @id, 166, 21, @on   -- sql:stmtrecompile / subclass
exec sp_trace_setevent @id, 45, 1, @on   -- sp:stmtcompleted / textdata
exec sp_trace_setevent @id, 41, 1, @on   -- sql:stmtcompleted / textdata
exec sp_trace_setevent @id, 166, 1, @on   -- sql:stmtrecompile / textdata
exec sp_trace_setevent @id, 45, 13, @on   -- sp:stmtcompleted / duration
exec sp_trace_setevent @id, 41, 13, @on   -- sql:stmtcompleted / durantion
exec sp_trace_setevent @id, 45, 16, @on   -- sp:stmtcompleted / reads
exec sp_trace_setevent @id, 41, 16, @on   -- sql:stmtcompleted / reads
exec sp_trace_setevent @id, 45, 17, @on   -- sp:stmtcompleted / writes
exec sp_trace_setevent @id, 41, 17, @on   -- sql:stmtcompleted / writes
exec sp_trace_setevent @id, 45, 18, @on   -- sp:stmtcompleted / cpu
exec sp_trace_setevent @id, 41, 18, @on   -- sql:stmtcompleted / cpu
exec sp_trace_setevent @id, 45, 5, @on   -- sp:stmtcompleted / line
exec sp_trace_setevent @id, 41, 5, @on   -- sql:stmtcompleted / line
exec sp_trace_setevent @id, 45, 34, @on   -- sp:stmtcompleted / objectname
exec sp_trace_setevent @id, 45, 29, @on   -- sp:stmtcompleted / nestlevel

exec sp_trace_setfilter @id, 12, 0, 0, @spid -- spid = @@spid
exec sp_trace_setfilter @id, 13, 0, 4, @minduration -- duration >= @min
exec sp_trace_setfilter @id, 16, 0, 4, @minreads -- reads >= @minreads
exec sp_trace_setfilter @id, 18, 0, 4, @mincpu -- cpu >= @mincpu

if @rollback=1 begin tran

exec sp_trace_setstatus @id, 1
exec (@batch)
exec sp_trace_setstatus @id, 0

if @@trancount>0 rollback

exec sp_trace_setstatus @id, 2

declare @results table (
    eventclass smallint,
    subclass smallint,
    textdata nvarchar(4000),
    objectname varchar(128),
    nesting smallint,
    linenumber smallint,
    duration numeric(18,3),
    reads int,
    cpu int,
    writes int,
    compile int,
    rccpu int,
    rcduration bigint,
    xplan xml,
    id bigint primary key
)

-- load trace
select @file = @file+'.trc'
insert @results
select eventclass, eventsubclass, textdata, objectname, nestlevel-2,
linenumber, duration/1000.0, reads, cpu, writes, 0, null, null, '', eventsequence
from fn_trace_gettable ( @file , default )
where eventsequence is not null

-- sequence query plans
if @plan is not null
update m set
  xplan = s.textdata
from @results s
cross apply(
  select top 1 * from @results
  where id > s.id and linenumber=s.linenumber and objectname=s.objectname
  order by id) m
where s.eventclass = @plan

-- sequence recompiles
update m set
compile = 1,
subclass = s.subclass,
rccpu = m.xplan.value('*[1]/*[1]/*[1]/*[1]/*[1]/*[1]/@compilecpu','int'),
rcduration = m.xplan.value('*[1]/*[1]/*[1]/*[1]/*[1]/*[1]/@compiletime','int')
from @results s
cross apply(
select top 1 * from @results
where id > s.id and textdata=s.textdata
order by id) m
where s.eventclass = 166

-- remove xplan variables
update @results set xplan.modify('delete *[1]/*[1]/*[1]/*[1]/*[1]/*[1]/@compiletime')
where xplan is not null
update @results set xplan.modify('delete *[1]/*[1]/*[1]/*[1]/*[1]/*[1]/@compilecpu')
where xplan is not null

-- total measure
select @total = nullif(max(case lower(@factor) when 'cpu' then cpu
when 'reads' then reads
when 'writes' then writes
else duration end),0),
@rcduration = sum(rcduration),
@rccpu = sum(rccpu),
@rc = sum(case when eventclass=166 then 1 else 0 end)
from @results

update @results set
rcduration = @rcduration,
rccpu = @rccpu,
compile = @rc
where objectname='sqltrace'

-- results
select case when objectname='sqltrace' then '' else
isnull(cast(nullif(floor((@total/2+100*sum(case lower(@factor) when 'cpu' then cpu+isnull(rccpu,0)
  when 'reads' then reads
  when 'writes' then writes
  else duration+isnull(rcduration,0) end))/@total),0) as varchar)+'%','') end as factor,
case when textdata like 'exec%' then '\---- '+textdata
  when textdata like '%statman%' then 'statistics -- '+textdata
  else textdata end as text,
case when objectname='sqltrace' or count(*)=1 then '' else cast(count(*) as varchar) end as calls,
case when objectname='sqltrace' then '' else cast(nesting as varchar) end as nesting,
case when objectname='sqltrace' then '' else objectname+' - '+cast(linenumber as varchar) end [object - line],
sum(duration) as duration,
isnull(cast(nullif(sum(cpu),0) as varchar),'') as cpu,
isnull(cast(nullif(sum(reads),0) as varchar),'') as reads,
isnull(cast(nullif(sum(writes),0) as varchar),'') as writes,
isnull(cast(nullif(sum(compile),0) as varchar),'') as compiles,
case subclass
  when 1 then 'local' when 2 then 'stats' when 3 then 'dnr'
  when 4 then 'set' when 5 then 'temp' when 6 then 'remote'
  when 7 then 'browse' when 8 then 'qn' when 9 then 'mpi'
  when 10 then 'cursor' when 11 then 'manual' else '' end reason,
case when sum(compile)>0 then isnull(cast(sum(rcduration) as varchar),'?') else '' end as rcduration,
case when sum(compile)>0 then isnull(cast(sum(rccpu) as varchar),'?') else '' end as rccpu,
cast(cast(xplan as nvarchar(4000)) as xml) xplan
from @results
where eventclass in (41,45)
group by nesting, objectname, linenumber, textdata, eventclass, subclass, cast(xplan as nvarchar(4000))
order by min(case when @order='' then id end),
sum(case lower(@order) when 'cpu' then cpu+isnull(rccpu,0)
   when 'reads' then reads
   when 'writes' then writes
   else duration+isnull(rcduration,0) end) desc
goto ret

help:
exec sp__usage @proc,'
Scope
    show execution info about code passed into @batch

Notes
    - originally from http://www.sommarskog.se/index.html

Parameters
    @batch          sql batch to analyse
    @minreads       min reads (logical)
    @mincpu         min cpu time (milliseconds)
    @minduration    min duration (microseconds)
    @factor         % (duration(default), reads, writes, cpu)
    @order          order (duration, reads, writes, cpu)
    @plans          include query plans - intentive (actual, estimated)
    @rollback       run in a transaction and rollback
    @timeout        set a maximum trace duration (seconds)

Result Set
==========
Name            Description
--------------- --------------------------------------------------------------------
Factor          The total percent of the chosen measure taken by this statement.
                See the parameter @factor above. Blank if the percentage is 0.
                If the total of @factor is 0, Factor will be blank for all columns.
Text            The text of the statement
Calls           Number of times this statement was executed if more than 1.
Nesting         On which nesting level the statement was executed.
Object - Line   SQL module and line number for the statement.
Duration        Duration for the statement in milliseconds with three decimals.
                See also the section An Issue with Durations
                in (http://www.sommarskog.se/sqlutil/sqltrace.html)
Reads           Number of reads for the statement according to the trace. Blank when 0.
Writes          Number of writes for the statement according to the trace. Blank when 0.
CPU             CPU time for the statement in milliseconds. Blank when when 0.
Compiles        Number of recompiles for the statement if any.
Reason          Reason why the statement was recompiled. See the table below for the meaning of the codes.
rcDuration      Time spent on recompiling the statement. This value is derived from the execution plan,
                and thus only populated if you supply a value for @plans. The value is in milliseconds.
                The value for the batch itself – which has sqltrace as the object –
                has the total recompilation time for the batch.
rcCPU           CPU time for the recompilation of the statement. Like rcDuration, only populated
                if you included execution plans in the trace.
XPlan           The execution plan for the statement. Blank if you did not specify a value for @plans.

Recompilation Reasons
=====================
Code    SubClassNo  Description
Local   1           Schema changed.
Stats   2           Statistics changed.
DNR     3           Deferred compile.
SET     4           SET option changed.
Temp    5           Temp table changed.
Remote  6           Remote rowset changed.
Browse  7           FOR BROWSE permissions changed.
QN      8           Query notification environment changed.
MPI     9           Partitioned view changed.
Cursor 10           Cursor option changed.
Manual 11           Option(RECOMPILE) or WITH RECOMPILE requested.
'

ret:
return @ret
end -- sp__util_sqltrace