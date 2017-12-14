/*  leave this
    l:see LICENSE file
    g:utility,utijob
    v:101116\s.zaglio: a bug near fn_config/fn__config sql
    v:100929.1000\s.zaglio: install a job monitor for other monitor
    t:exec sp__job_monitor 'stezagl@tin.it','lupin'
*/
CREATE proc sp__job_monitor
    @to         nvarchar(1024) = null,
    @smtp       nvarchar(1024) = null,
    @jobs       nvarchar(1024) = null,
    @excludes   nvarchar(1024) = null,
    @h          int            = null,
    @dbg int=0
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard api: 0=ok -1=help, any=error id
select @proc='sp__job_monitor', @ret=0

if @to is null or @smtp is null goto help

-- declarations
declare
    @at sysname,@sp nvarchar(4000),@mins int,
    @jname sysname,@sql nvarchar(4000)

-- initialization
if left(@smtp,2)='##' and right(@smtp,2)='##'
    begin
    select @sql='select @smtp=convert(sysname,dbo.fn__config('''
               +substring(@smtp,3,len(@smtp)-4)+''',null))'
    if @dbg=1 exec sp__printf '-- %s',@sql
    exec sp_executesql @sql,'@smtp sysname out',@smtp=@smtp out
    end
else
    begin
    if left(@smtp,1)='#' and right(@smtp,1)='#'
        begin
        select @sql='select @smtp=convert(sysname,dbo.fn_config('''
                   +substring(@smtp,2,len(@smtp)-2)+''',null))'
        if @dbg=1 exec sp__printf '-- %s',@sql
        exec sp_executesql @sql,'@smtp sysname out',@smtp=@smtp out
        end
    end

select
    @jname='process montor '+dbo.fn__hex(dbo.fn__crc32(@to)),
    @h=isnull(@h,2),
    @at=convert(sysname,@h)+'h',
    @mins=@h*60,
    @sp='exec sp__job_status @mins='+convert(sysname,@mins)+
        ',@jobs='''+coalesce(@jobs,'%')+''''+
        coalesce(',@excludes='''+@excludes+'''','')+
        ',@to='''+@to+''''+
        ',@body=''report jobs of:'+@@servername+''''+
        ',@smtp='''+@smtp+''''
-- ===================================================================== body ==
if @dbg=1 exec sp__printf 'sp:%s',@sp
exec sp__job
    @jname,
    @sp=@sp,
    @at=@at,
    @opt='sql'

goto ret

-- =================================================================== errors ==

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
scope
    install a job that monitor other processes

parameters
    @to     email;email;email which send list of failures
    @smtp   smtp server; a special syntax can be used here:
                ##var_name##    read value using "fn__config(''var_name'',null)"
                #var_name#      read value using "fn_config(''var_name'',null)"
    @jobs   by default monitor all jobs but can specify
            xxx|yyy|... to monitor all jobs that start with xxx or yyy
    @excludes   to excludes jobs that start with xxx or yyy
    @h      by default is every 2 hours, the slot time to monitor

notes
    the process monitor will have name "process monitor xxx"
    where xxx is a crc code of @emails.

examples
    exec sp__job_monitor ''stezagl@tin.it'',''lupin''
    exec sp__job_monitor ''stefano.zaglio@seltris.it'',''lupin''
    exec sp__job ''process monitor#'',# -- delete all monitors
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__job_monitor