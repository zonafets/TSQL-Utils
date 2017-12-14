/*  leave this
    l:see LICENSE file
    g:utility,perf
    v:100522.1000\s.zaglio: list performance counters
    t:sp__perf_info "database","trans","total",@dbg=1
*/
CREATE proc sp__perf_info
    @obj    sysname = null,
    @cnt    sysname = null,
    @inst   sysname = null,
    @dbg int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    @sql nvarchar(4000),
    @objects nvarchar(4000),
    @counters nvarchar(4000),
    @instances nvarchar(4000),
    @tbl sysname
-- =========================================================== initialization ==

select @objects='select distinct object_name as objects from %tbl% order by 1'
select @counters='select distinct counter_name as counters from %tbl% order by 1'
select @instances='select distinct instance_name as instances from %tbl% order by 1'
select
    @obj=isnull(@obj,''),
    @cnt=isnull(@cnt,''),
    @inst=isnull(@inst,'')

select @sql='
select * from %tbl%
where 1=1
and object_name like ''%%obj%%''
and counter_name like ''%%cnt%%''
and instance_name like ''%%inst%%''
'

if dbo.fn__isMSSQL2K()=1 select @tbl='sysperfinfo'
else select @tbl='sys.dm_os_performance_counters'

exec sp__str_replace @objects out,'%tbl%',@tbl
exec sp__str_replace @counters out,'%tbl%',@tbl
exec sp__str_replace @instances out,'%tbl%',@tbl
exec sp__str_replace @sql out,'%tbl%|%obj%|%cnt%|%inst%',@tbl,@obj,@cnt,@inst

-- ======================================================== second params chk ==

if @obj='' and @cnt='' and @inst='' goto help

-- ===================================================================== body ==
if @dbg=1 exec sp__printsql @sql
exec(@sql)

goto ret

-- =================================================================== errors ==

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    list performance counters

Parameters
    @obj,

Examples
    -- show total transactions
    sp__perf_info "database","trans","total"

-- Counter: Recommended value
SQLServer:Memory Manager\Memory Grants Pending:0
SQServer:Buffer Manager\Buffer Hit cache Ratio:>95%
SQLServer:Buffer Manager\Page life Expectancy:>300
SQLServer:Buffer Manager\Free Pages:>300
SQLServer:Buffer Manager\Free list Stalls/Sec:0
Memory Grants Pending represents the total number of processes waiting for a workspace memory grant, a non-zero value indicates a memory problem
Buffer Hit Cache Ratio represets the percentage of time SQL was able to get the page from buffer pool instead of having to do a hard read from disk
Page Life Expectancy shows how long a data page stays in the buffer cache. 300 seconds is the industry-accepted threshold for this counter. Anything less than a 300-second average over an extended period of time tells you that the data pages are being flushed from memory too frequently and SQL has to do hard reads from disk fullfill requests, hard reads require CPU/lock resources etc. if there is a sudden drop in Page life expectancy then we need to check Checkpoints Pages/sec counter When a checkpoint occurs in the system, the dirty data pages in the buffer cache are flushed to disk, causing the Page life Expectancy value to drop.
Free Pages represent the total number of pages on all free lists, this number in general should be above 300 the hight the better, a lower number would be ok if Free list stalls/sec is a zero value.
Free list Stalls/Sec represents Number of requests per second that had to wait for a free page.

if you have defined that your server is under memory pressure the second thing to do to check the components that consume the memory.

-- list of objects, counters, instances --
'
exec sp__select_astext @objects,@header=1
exec sp__printf ''
exec sp__select_astext @counters,@header=1
exec sp__printf ''
exec sp__select_astext @instances,@header=1

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__perf_info