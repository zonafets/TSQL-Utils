/*  leave this
    l:see LICENSE file
    g:utility
    k:server,instance,port,ip,address
    v:130517\s.zaglio: get info about server
*/
CREATE proc sp__info_server
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
    -- @run bit,
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    -- @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
    --     |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
-- if  @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==
select * into #tmp from fn__server_info()
exec sp__select_asform '#tmp',@opt='noh|dot'
drop table #tmp

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    [write here a short desc]

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
end catch   -- proc sp__info_server