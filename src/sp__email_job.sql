/*  leave this
    l:see LICENSE file
    g:utility
    k:deferred,at,time,date
    r:120101\s.zaglio: manage deferred emails
*/
CREATE proc sp__email_job
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

/*
tid         flags   rid         pid     cod         dt
email       type    rply        fwd     null
to                  email       copy    txt
subj                email       copy    txt
body                email       copy    txt
cc                  email       copy    txt
bcc                 email       copy    txt
attach_name         email       copy    file name
attach_body type    attach_name copy    blob
grp         type    grp         email   name
*/

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    manage deferred emails

Notes
    (this is only a memo to not loose the knowledge)
    * the default job plan is 1h

Parameters
    @opt    options
            install     install the job
            list        list pending emails
            run         send pending emails now
            ena         enable the job
            dis         disable the job
            30mi        set plan of job every 30 minutes

Examples
    sp__email_job                       -- show this help

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
end catch   -- proc sp__email_job