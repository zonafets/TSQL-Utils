/*  leave this
    l:see LICENSE file
    g:utility
    v:140109\s.zaglio: check
    t:sp__script_utility_setup_test run
*/
CREATE proc sp__script_utility_setup_test
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp (not correct if called by remote sp)

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
    @run bit

-- =========================================================== initialization ==
select
    @run=charindex('|run|',@opt)

-- ======================================================== second params chk ==
if @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- test if fn__job work in this system
exec @ret=sp__job_test @opt='setup'


-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test the full functionality of the utility that can fail depending
    from MSSQL version or OS configuration

Parameters
    [param]     [desc]
    @opt        options
                run tun tests
    @dbg        debug level
                1   basic info and do not execute dynamic sql
                2   more details (usually internal tables) and execute dsql
                3   basic info, execute dsql and show remote info

Examples
    sp__script_utility_setup_test run
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
end catch   -- proc sp__script_utility_setup_test