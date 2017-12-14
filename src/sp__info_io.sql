/*  leave this
    l:see LICENSE file
    g:utility
    k:disk,drives,files,virtual,db,performance,statistics,io
    v:130707\s.zaglio: give info about disk io
    c:from david wiseman (http://www.wisesoft.co.uk)
*/
CREATE proc sp__info_io
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
-- if  @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- i/o stats by database
select d.name as databasename,
    round(cast(sum(num_of_bytes_read+num_of_bytes_written) as float) / sum(sum(num_of_bytes_read+num_of_bytes_written)) over() *100,2) as [% total i/o],
    round(cast(sum(num_of_bytes_read) as float) / sum(sum(num_of_bytes_read)) over() *100,2) as [% read i/o],
    round(cast(sum(num_of_bytes_written) as float) / sum(sum(num_of_bytes_written)) over() *100,2) as [% write i/o],
    round(cast(sum(num_of_bytes_read+num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [total gb],    
    round(cast(sum(num_of_bytes_read)/(1024*1024*1024.0) as float),2) as [read gb],
    round(cast(sum(num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [write gb],
    sum(io_stall) as [i/o total wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
            --    i/o stall in days
            + cast(sum(io_stall) / 86400000 as varchar)
            --  length of max i/o stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall)/1000,0),114),8) as [i/o total wait time {days} hh:mm:ss],
    sum(io_stall_read_ms) as [i/o read wait ms]    ,
    isnull(nullif(right(replicate('0',
            --  length of max i/o read stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
            --    i/o read stall in days
            + cast(sum(io_stall_read_ms) / 86400000 as varchar)
            --  length of max i/o read stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o read stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_read_ms)/1000,0),114),8) as [i/o read wait time {days} hh:mm:ss]    ,
    sum(io_stall_write_ms) as [i/o write wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o write stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
            --    i/o write stall in days
            + cast(sum(io_stall_write_ms) / 86400000 as varchar)
            --  length of max i/o write stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o write stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_write_ms)/1000,0),114),8) as [i/o write wait time {days} hh:mm:ss],    
    sum(io_stall) / nullif(sum(num_of_reads+num_of_writes),0)     as [avg i/o wait ms],
    sum(io_stall_read_ms) / nullif(sum(num_of_reads),0)     as [avg read i/o wait ms],
    sum(io_stall_write_ms) / nullif(sum(num_of_writes),0)     as [avg write i/o wait ms],
    sum(num_of_bytes_read+num_of_bytes_written)/nullif(sum(num_of_reads+num_of_writes),0) as [avg i/o bytes],
    sum(num_of_bytes_read)/nullif(sum(num_of_reads),0) as [avg read i/o bytes],
    sum(num_of_bytes_written)/nullif(sum(num_of_writes),0) as [avg write i/o bytes],    
    cast(max(sample_ms) / 86400000 as varchar)
            -- i/o write stall formatted to hh:mm:ss    
             + ' ' + left(convert(varchar,dateadd(s,max(sample_ms)/1000,0),114),8) as [sample time {days} hh:mm:ss]      
from sys.dm_io_virtual_file_stats(null,null) vfs
join sys.databases d on vfs.database_id = d.database_id
group by d.name
order by [% total i/o] desc;

-- i/o stats by file
select d.name as databasename,
    mf.name as logical_name,
    mf.physical_name,
    round(cast(sum(num_of_bytes_read+num_of_bytes_written) as float) / sum(sum(num_of_bytes_read+num_of_bytes_written)) over() *100,2) as [% total i/o],
    round(cast(sum(num_of_bytes_read) as float) / sum(sum(num_of_bytes_read)) over() *100,2) as [% read i/o],
    round(cast(sum(num_of_bytes_written) as float) / sum(sum(num_of_bytes_written)) over() *100,2) as [% write i/o],
    round(cast(sum(num_of_bytes_read+num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [total gb],    
    round(cast(sum(num_of_bytes_read)/(1024*1024*1024.0) as float),2) as [read gb],
    round(cast(sum(num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [write gb],
    sum(io_stall) as [i/o total wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
            --    i/o stall in days
            + cast(sum(io_stall) / 86400000 as varchar)
            --  length of max i/o stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall)/1000,0),114),8) as [i/o total wait time {days} hh:mm:ss],
    sum(io_stall_read_ms) as [i/o read wait ms]    ,
    isnull(nullif(right(replicate('0',
            --  length of max i/o read stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
            --    i/o stall in days
            + cast(sum(io_stall_read_ms) / 86400000 as varchar)
            --  length of max i/o read stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o read stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_read_ms)/1000,0),114),8) as [i/o read wait time {days} hh:mm:ss]    ,
    sum(io_stall_write_ms) as [i/o write wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o write stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
            --    i/o write stall in days
            + cast(sum(io_stall_write_ms) / 86400000 as varchar)
            --  length of max i/o write stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o write stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_write_ms)/1000,0),114),8) as [i/o write wait time {days} hh:mm:ss],
    sum(io_stall) / nullif(sum(num_of_reads+num_of_writes),0)     as [avg i/o wait ms],
    sum(io_stall_read_ms) / nullif(sum(num_of_reads),0)     as [avg read i/o wait ms],
    sum(io_stall_write_ms) / nullif(sum(num_of_writes),0)     as [avg write i/o wait ms],
    sum(num_of_bytes_read+num_of_bytes_written)/nullif(sum(num_of_reads+num_of_writes),0) as [avg i/o bytes],
    sum(num_of_bytes_read)/nullif(sum(num_of_reads),0) as [avg read i/o bytes],
    sum(num_of_bytes_written)/nullif(sum(num_of_writes),0) as [avg write i/o bytes],
    cast(max(sample_ms) / 86400000 as varchar)
            -- i/o write stall formatted to hh:mm:ss    
             + ' ' + left(convert(varchar,dateadd(s,max(sample_ms)/1000,0),114),8) as [sample time {days} hh:mm:ss]                                 
from sys.dm_io_virtual_file_stats(null,null) vfs
join sys.databases d on vfs.database_id = d.database_id
join sys.master_files mf on vfs.file_id = mf.file_id and mf.database_id = vfs.database_id
group by d.name,mf.name,mf.physical_name
order by [% total i/o] desc;

-- i/o stats by drive
select left(mf.physical_name,3) as drive,
    round(cast(sum(num_of_bytes_read+num_of_bytes_written) as float) / sum(sum(num_of_bytes_read+num_of_bytes_written)) over() *100,2) as [% total i/o],
    round(cast(sum(num_of_bytes_read) as float) / sum(sum(num_of_bytes_read)) over() *100,2) as [% read i/o],
    round(cast(sum(num_of_bytes_written) as float) / sum(sum(num_of_bytes_written)) over() *100,2) as [% write i/o],
    round(cast(sum(num_of_bytes_read+num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [total gb],    
    round(cast(sum(num_of_bytes_read)/(1024*1024*1024.0) as float),2) as [read gb],
    round(cast(sum(num_of_bytes_written)/(1024*1024*1024.0) as float),2) as [write gb],
    sum(io_stall) as [i/o total wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
            --    i/o stall in days
            + cast(sum(io_stall) / 86400000 as varchar)
            --  length of max i/o stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall)/1000,0),114),8) as [i/o total wait time {days} hh:mm:ss],
    sum(io_stall_read_ms) as [i/o read wait ms]    ,
    isnull(nullif(right(replicate('0',
            --  length of max i/o read stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
            --    i/o stall in days
            + cast(sum(io_stall_read_ms) / 86400000 as varchar)
            --  length of max i/o read stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_read_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o read stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_read_ms)/1000,0),114),8) as [i/o read wait time {days} hh:mm:ss]    ,
    sum(io_stall_write_ms) as [i/o write wait ms],
    isnull(nullif(right(replicate('0',
            --  length of max i/o write stall in days over resultset (for dynamic padding - replicate)
            len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
            --    i/o write stall in days
            + cast(sum(io_stall_write_ms) / 86400000 as varchar)
            --  length of max i/o write stall in days over resultset (for dynamic padding - right)    
            ,len(isnull(cast(nullif(max(sum(io_stall_write_ms)) over() /86400000,0) as varchar),'')))
             + ' ',' '),'')
            -- i/o write stall formatted to hh:mm:ss    
             + left(convert(varchar,dateadd(s,sum(io_stall_write_ms)/1000,0),114),8) as [i/o write wait time {days} hh:mm:ss],
    sum(io_stall) / nullif(sum(num_of_reads+num_of_writes),0)     as [avg i/o wait ms],
    sum(io_stall_read_ms) / nullif(sum(num_of_reads),0)     as [avg read i/o wait ms],
    sum(io_stall_write_ms) / nullif(sum(num_of_writes),0)     as [avg write i/o wait ms],
    sum(num_of_bytes_read+num_of_bytes_written)/nullif(sum(num_of_reads+num_of_writes),0) as [avg i/o bytes],
    sum(num_of_bytes_read)/nullif(sum(num_of_reads),0) as [avg read i/o bytes],
    sum(num_of_bytes_written)/nullif(sum(num_of_writes),0) as [avg write i/o bytes],
    cast(max(sample_ms) / 86400000 as varchar)
            -- i/o write stall formatted to hh:mm:ss    
             + ' ' + left(convert(varchar,dateadd(s,max(sample_ms)/1000,0),114),8) as [sample time {days} hh:mm:ss]                                 
from sys.dm_io_virtual_file_stats(null,null) vfs
join sys.databases d on vfs.database_id = d.database_id
join sys.master_files mf on vfs.file_id = mf.file_id and mf.database_id = vfs.database_id
group by left(mf.physical_name,3)
order by [% total i/o] desc;

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    returns io statistics by: database,file,drive

Parameters
    [param]     [desc]
    @opt        options
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

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
end catch   -- proc sp__info_io