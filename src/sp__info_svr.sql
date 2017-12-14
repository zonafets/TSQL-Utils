/*  leave this
    l:see LICENSE file
    g:utility
    k:virtual,file,log,vlf,enterprise,size,db,dbs,server,status
    v:130107\s.zaglio: get global info about entire server
    todo:integrate sp__util_vlf
    t:sp__info_svr detail
*/
CREATE proc sp__info_svr
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
    @sel bit,@print bit,@detail bit,
    @end_declare bit

-- =========================================================== initialization ==
select
    @detail=charindex('|detail|',@opt),
    @sel=charindex('|sel|',@opt),
    @print=charindex('|print|',@opt),
    @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
        |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @end_declare=1

if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
-- if  @run=0 goto help

-- =============================================================== #tbls init ==
create table #dbs(
    srv sysname,
    db sysname,
    lname sysname,
    pname nvarchar(1024),
    size int,
    um nvarchar(4),
    density float null,
    unusedvlf int null,
    usedvlf int null,
    totalvlf int null
    )

-- ===================================================================== body ==
if @detail=1
insert #dbs(srv,db,lname,pname,size,um)
select
    @@servername,
    db_name(database_id) as db,
    name as logical_name,
    physical_name,
    (size*8)/1024 size,
    'MB' um
from sys.master_files

insert #dbs(srv,db,lname,pname,size,um)
select @@servername,'*','*','*',
    case
    when cast(sum(sizemb)/(1024.0*1024.0) as int)=0
    then cast(sum(sizemb)/1024.0 as int)
    else cast(sum(sizemb)/(1024.0*1024.0) as int)
    end as size,
    case
    when cast(sum(sizemb)/(1024.0*1024.0) as int)=0
    then 'GB'
    else 'TB'
    end as size_um
from (
    select
        db_name(database_id) as databasename,
        name as logical_name,
        physical_name, (size*8)/1024 sizemb
    from sys.master_files
    ) sizes

if @sel=1
    select * from #dbs
else
    begin
    exec sp__select_astext 'select * from #dbs'
    -- separate from help
    exec sp__prints '8<'
    end

-- ================================================================== dispose ==
dispose:
drop table #dbs

goto help

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    get global info about entire server

Notes
    lname is logical name
    pname is physical name

Parameters
    @opt    options
            detail      show detail about all databases, not only the sum

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
end catch   -- proc sp__info_svr