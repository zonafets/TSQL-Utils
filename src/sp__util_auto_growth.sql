/*  leave this
    l:see LICENSE file
    g:utility
    k:monitor,database,performance,auto,grouth
    v:130227\s.zaglio: identifying how often an auto-growth event has occurred
    c:
        from
        https://www.simple-talk.com/sql/database-administration/sql-server-database-growth-and-autogrowth-settings/
    t:sp__util_auto_growth run
*/
create proc sp__util_auto_growth
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
if @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

declare @filename nvarchar(1000);
declare @bc int;
declare @ec int;
declare @bfn varchar(1000);
declare @efn varchar(10);

-- get the name of the current default trace
select @filename = cast(value as nvarchar(1000))
-- select *
from ::fn_trace_getinfo(default)
where traceid = 1 and property = 2;

-- rip apart file name into pieces
set @filename = reverse(@filename);
set @bc = charindex('.',@filename);
set @ec = charindex('_',@filename)+1;
set @efn = reverse(substring(@filename,1,@bc));
set @bfn = reverse(substring(@filename,@ec,len(@filename)));

-- set filename without rollover number
set @filename = @bfn + @efn

-- process all trace files
select
  ftg.starttime
,te.name as eventname
,db_name(ftg.databaseid) as databasename
,ftg.filename
,(ftg.integerdata*8)/1024.0 as growthmb
,(ftg.duration/1000)as durms
from ::fn_trace_gettable(@filename, default) as ftg
inner join sys.trace_events as te on ftg.eventclass = te.trace_event_id
where (ftg.eventclass = 92  -- date file auto-grow
    or ftg.eventclass = 93) -- log file auto-grow
order by ftg.starttime

-- sp__find 'fn_trace_getinfo'

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    identifying how often an auto-growth event has occurred

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
end catch   -- proc sp__util_auto_growth