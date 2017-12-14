/*  leave this
    l:see LICENSE file
    g:utility
    k:job,test,auto,find,name,running
    v:140103\s.zaglio: callable from sp__utility_setup
    v:130209\s.zaglio: test func fn__job
    t:sp__job_test @dbg=1
*/
CREATE proc sp__job_test
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
    @run bit,@setup bit,
    @sp sysname

-- =========================================================== initialization ==
select @run=charindex('|run|',@opt),@setup=charindex('|setup|',@opt)

-- ======================================================== second params chk ==

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

if @run=0
    begin
    select @sp=@proc+' @opt=''run'''
    -- delete prev job
    exec sp__job @proc,'#'
    exec sp__job @proc,@sp,@opt='sql|run|nolog'
    -- exec sp__job_wait @proc
    waitfor delay '00:00:01'
    if @dbg=0 exec sp__job @proc,'#'
    if object_id('tmp_sp__job_test') is null raiserror('test failed',16,1)
    if @setup=0 select * from tmp_sp__job_test
    drop table tmp_sp__job_test
    end
else
    begin
    if not object_id('tmp_sp__job_test') is null drop table tmp_sp__job_test
    create table tmp_sp__job_test(
        job_id sql_variant null,name sql_variant null,
        loginname sql_variant null,login sql_variant null,
        ologin sql_variant null,ja sql_variant null
        )
    insert into tmp_sp__job_test(job_id,name,loginname,ja)
    select *,dbo.fn__job_agent()
    from fn__job(@@spid)
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

if @setup=1 goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test if fn__job works in this system;
    if it do not work, the sp__job_status and all the SP called from a job,
    do not understand that they are running into a job.

Parameters
    [param]     [desc]
    @opt        options
                run     run the test (called by itself from a temporary job)
                setup   when called by sp__utility_setup
    @dbg        debug info
                1   do not delete temporary job

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
end catch   -- proc sp__job_test