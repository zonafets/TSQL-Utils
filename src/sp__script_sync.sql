/*  leave this
    l:see LICENSE file
    g:utility,trace
    r:110418\s.zaglio: added check of presence of utils
    r:110321\s.zaglio: syncronize new updates
*/
CREATE proc sp__script_sync
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)

-- check if utilities are regenerating
if object_id('fn__str_quote') is null goto ret
if object_id('sp__isjob') is null goto ret
if object_id('fn__config') is null goto ret
if object_id('sp__config') is null goto ret
if object_id('sp__job') is null goto ret

select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==
declare @ok int
-- xp_cmdshell 'type C:\DOCUME~1\NETWOR~1\IMPOST~1\Temp\utility_sp__script_sync_log.txt'
exec @ok=sp__isjob @@spid,@dbg=0
-- select @ok=dbo.fn__isjob(@@spid)
if @ok=1 goto sync

if @opt='||' goto help

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==
-- if the job is running, do not execute it again
if convert(bit,dbo.fn__config('script_sync',0))=0
    begin
    -- lock the job launch
    -- sp__config '%'
    exec sp__config 'script_sync',1
    exec sp__job 'SCRIPT_SYNC',@sp='sp__script_sync',@opt='run|quiet'
    end

goto ret

sync:

-- wiat 5 seconds in case that a second run occur
print 'synchronizing...'
-- update log_ddl with (readpast) set udt=getdate()

-- exec sp__sync 'log_ddl',@opt='>'

waitfor delay '00:00:05'
exec sp__config 'script_sync',0
goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    [write here a short desc]

Parameters
    [param]     [desc]

Examples
    [exam ple]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_sync