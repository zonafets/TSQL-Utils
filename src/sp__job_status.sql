/*  leave this
    l:see LICENSE file
    g:utility
    v:140103\s.zaglio: around backward compatibility near @mins=-1
    v:131223\s.zaglio: added send of email even if problem with attachment
    v:131129\s.zaglio: wait more time for problem of attachment locked
    r:131127.1100\s.zaglio: some adjustements about parameters and correct help
    r:131125\s.zaglio: integrating fn__job_Status to send emails every 4,16,64,256
    r:131122\s.zaglio: integrating fn__job_Status and fn__config_app
    r:131117\s.zaglio: pretty prints and removed sp4,8; adapting to fn__job_status
    r:131116\s.zaglio: set @mins to -1 when @step specified and added try-catch
    v:130409\s.zaglio: when @mins<0 unqueue sp4/sp8 options
    v:121210\s.zaglio: a bug cause by sp__select_astext
    v:120726\s.zaglio: added @header=1 on sp__select_astext
    v:111130\s.zaglio: body into html and added ref and last_upd
    v:110715\s.zaglio: better messages
    v:110212\s.zaglio: better help
    v:100927.1010\s.zaglio: moved @mins parameter and a bug near list and @mins=-1
    v:100926\s.zaglio: added with (nolock) and -1 on multi job
    v:100919.1100\s.zaglio: added log in opt to print txts (autoprinted if step is 1)
    v:100919.1000\s.zaglio: reordered params and added opt
    v:100919\s.zaglio: added slot management
    v:100724.1000\s.zaglio: a bug near -1 (last error) and calc when @mins>0
    v:100626\s.zaglio: a bug near time
    v:100625\s.zaglio: a little bug and optimization
    v:100615\s.zaglio: added -1 option and a bug near selection
    v:100612\s.zaglio: done and tested
    r:100424\s.zaglio: send report of failed job of last hour
    t:sp__job_status '%status%','raiserror',@opt='log'
    t:sp__job_status '%status%','raiserror',@opt='log|sel'
    t:sp__job_status '%status%',@mins=2440,@opt='log'
    t:update cfg set val='X' where [key]='job_status.test'
    t:update cfg set val=' ' where [key]='job_status.test'
    t:sp__job 'sp__job_status_test',@opt='run'
    t:sp__job_status '%',@opt='sel'
    t:sp__job_status '%',@opt='sel',@mins=2880
    t:select * from fn__job_status('%status%',default,'fle')
    t:msdb..sp_help_jobhistory @job_name='sp__job_status_test'
    t:sp__job_status '%status%',@mins=-1,@to='*'
*/
CREATE proc [dbo].[sp__job_status]
    @jobs nvarchar(4000) = null,    -- filters for name%|name%|...
    @steps nvarchar(4000) = null,   -- filters for step|step|...
    @mins int     = null,           -- failed of lasts minutes or job name
    @excludes nvarchar(4000) = null,
    @attach bit = null,
    @to nvarchar(4000) = null,      -- send status to this email
    @body nvarchar(4000) = null,
    @smtp sysname = null,
    @ref sysname = null,
    @opt sysname = null,
    @dbg bit = 0
as
begin try
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

declare @job_id uniqueidentifier

select @job_id=job_id,@jobs=isnull(name,@jobs) from fn__job(@@spid)

if @jobs is null goto help

if @mins<-1 or @mins=0 goto help

-- filters
declare @filters table (id int identity,tid tinyint,dat sysname)

if @jobs is null
    insert @filters select 1,'%'

if @steps is null
    insert @filters select 2,'%'
else
    begin
    insert @filters
    select 2,token
    from dbo.fn__str_table(@steps,'|')
    end

if not @excludes is null
    insert @filters
    select 3,'%'+token+'%'
    from dbo.fn__str_table(@excludes,'|')

-- ==================================================== variable declarations ==

declare
    @previousdate datetime,
    @id int,@hh int, @n int,@i int,
    @logfile nvarchar(512),@cmd nvarchar(4000),
    @header int,
    @sql nvarchar(4000),
    @attaches nvarchar(4000),
    -- options
    @log bit,@ok bit,@sel bit,@nep bit,@err bit,@back bit,
    @fn_opt sysname

create table #src(lno int identity,line nvarchar(4000))

-- ===================================================================== init ==

select
    @attach=isnull(@attach,1),
    @back=case @mins when -1 then 1 else 0 end,
    @mins=nullif(@mins,-1)

if @mins is null
    select @mins=7*24*60,@fn_opt='fle'

select
    @to=nullif(@to,''),
    @smtp=nullif(@smtp,''),
    @ok=charindex('|ok|',@opt),
    @sel=charindex('|sel|',@opt),
    @log=charindex('|log|',@opt),
    @nep=charindex('|nep|',@opt)

-- ===================================================================== body ==

if not @job_id is null or @to='*'
    begin
    select @to=nullif(@to,'*')

    if @to is null
        select @to=isnull(@to,cast(
                    dbo.fn__config_app('.SUPPORT_EMAIL|job_status.to',default)
                    as nvarchar(4000)
                    ))
    if @smtp is null
        select @smtp=isnull(@smtp,cast(
                        dbo.fn__config_app('.MAIL_SMTP_SERVER|'+
                                           'job_status.smtp|smtp_server',default)
                        as nvarchar(4000)
                        ))

    if @to is null or @smtp is null
        raiserror('@smtp or @to not specified',16,1)

    exec sp__printf '-- auto job idf:%s to:%s(%s)',@jobs,@to,@smtp
    end

if not @job_id is null
    begin

    -- prevent continuos resend of message error
    if @nep=0
        begin
        select top 1 @err=err,@n=n
        from fn__job_status(@jobs,default,'fle')
        where id=@job_id
        if @err=1
            begin
            if @n>4 and not @n in (16,64,128,256)
                begin
                exec sp__printf '-- skipped because more than 4 errors'
                goto ret
                end
            end
        else
            goto ret
        end
    -- select @mins=-1 this do not work properly
    end -- auto job determination

-- ====================================================== read all job status ==

select
    h.server,
    s.database_name as db,
    fjn.[name] as job,
    h.step_id as sid,
    case when h.sql_severity>10 then 'X' else '' end S,
    dbo.fn__str_pad(convert(sysname,h.run_date),8,default,default,default)
    as run_date,
    dbo.fn__str_pad(convert(sysname,h.run_time),6,default,default,default)
    as run_time,
    fjn.n as n,
    h.run_duration secs,
    s.step_name as step,
    isnull((select
            convert(sysname,si.val1)+'\'+convert(sysname,si.val2)
            from dbo.fn__script_info(s.command,'vr',0) si
            ),replace(replace(replace(
              left(s.command,40)+case when len(s.command)>40 then '...' else '' end,
              char(13),' '),char(10),' '),'  ',' ')
        )
    as last_upd,
    -- h.sql_severity,
    left('..'+
    replace(replace(
    replace(replace(
    replace(replace(
    replace(replace(
    replace(replace(
    h.message,
    '[SQLSTATE 01000]',''),'(Message 50000)',''),
    '[SQLSTATE 42000]',''),'(Error 50000)',''),
    char(13),' '),char(10),' '),
    '..',''),'The step ',''),
    '  ',' '),'(Message 0)','')
    ,128) as [message],
    s.output_file_name

into #failures

from fn__job_status(@jobs,@mins,@fn_opt) fjn
join msdb.dbo.sysjobhistory h with (nolock)
  on h.job_id=fjn.id
 and h.run_date=fjn.run_date
 and h.run_time between fjn.from_time and fjn.run_time
join msdb.dbo.sysjobsteps s with (nolock)
  on h.job_id = s.job_id and h.step_id=s.step_id
join @filters flts on flts.tid=2 and s.step_name like flts.dat
left join @filters fltexj on fltexj.tid=3 and h.message like fltexj.dat
where charindex('exec sp__job_status',s.command)=0
and left(s.command,14)!='sp__job_status'
and fltexj.id is null
order by h.run_date desc,server,row desc,h.run_time desc,h.step_id desc

-- ================================================================= @mins=-1 ==

-- if calling from job...
if not @job_id is null or @back=1
    begin
    delete f
    from #failures f
    left join (
        select top 1 *
        from #failures
        order by run_date desc,run_time desc,sid desc
        ) ff
    on ff.run_date=f.run_date and ff.run_time=f.run_time and ff.sid=f.sid
    where ff.sid is null

    if 'X'!=(
        select top 1 s
        from #failures
        order by run_date desc,run_time desc,sid desc
        )
        goto ret

    end -- from job

if @attach=1
    begin
    /*  111130\s.zaglio: converted into html-body
        select @attaches='select * from #failures order by instance_id desc' */
    select @attaches=coalesce(@attaches+';','')+output_file_name
    from (
        -- optimize files for more steps
        select distinct output_file_name
        from #failures
        where coalesce(output_file_name,'')!=''
        ) sq

    if @dbg=1 exec sp__printf '-- %s:attaches:%s',@proc,@attaches
    end

select @n=count(*) from #failures
if @n>0
    begin
    -- sp__job_status @mins=-1,@jobs='spj_test',@opt='ok',@dbg=1
    if @dbg=1 exec sp__printf '-- %s:%d failed job steps found for jobs %s',
                              @proc,@n,@jobs
    if not @to is null
        begin

        insert #src select '<html><body>'
        insert #src select 'jobs:'+@jobs

        if not @body is null insert #src select @body

        exec sp__select_astext '
        select
            SERVER,DB,JOB,SID,S,RUN_DATE,RUN_TIME,N,STEP,LAST_UPD,
            MESSAGE
        from #failures
        order by run_date desc,run_time desc,sid desc
        ',
        @out='#src',@opt='html',@header=1,@dbg=0

        insert #src select '</body></html>'

        declare @subj sysname
        select @subj=quotename(dbo.fn__servername(null))
                    +'.sp__job_status failed steps for jobs: '
                    +coalesce(@jobs,'ALL')

        -- retry because some time the agent block the log
        select @n=1
        while @n<4
            begin try
            exec sp__printf '-- send email (%d)',@n
            exec sp__email
                @to=@to,
                @subj=@subj,
                @body='#src',
                @attach=@attaches,
                @smtp=@smtp,
                @dbg=@dbg
            break
            end try
            begin catch
            select @n=@n+1
            if @n=4
                begin
                select @sql=error_message()
                exec sp__printf '%s',@sql
                insert #src select '<br><font color="#FF0000">'+@sql+'<br>'
                insert #src select @attaches+'</font><br>'
                exec sp__email
                    @to=@to,
                    @subj=@subj,
                    @body='#src',
                    @smtp=@smtp,
                    @dbg=@dbg
                end
            else
                waitfor delay '00:00:02'
            end catch

        end -- @n>0

    else

        begin
        -- show only to console
        if @ok=0
        -- and charindex('|log|',@opt)=0
        --or ((select count(*) from #failures)>1
            begin
            -- then show steps with log
            select @sql='
                select * from #failures
                order by run_date desc,run_time desc,sid desc
                '
            if @n>20 select @header=2 else select @header=1
            if @sel=1 exec(@sql)
            else exec sp__select_astext @sql,@header=@header
            end

        -- ##########################
        -- ##
        -- ## print log
        -- ##
        -- ########################################################

        if @log=1
            begin
            -- first show steps without log
            if exists(
                select top 1 null from #failures
                where isnull(output_file_name,'')=''
                )
                begin
                select @sql='
                    select ''step without log'' info,* from #failures
                    where isnull(output_file_name,'''')=''''
                    order by run_date desc,run_time desc,sid desc
                    '

                if @sel=1 exec(@sql)
                else
                    begin
                    exec sp__printf ''
                    exec sp__select_astext @sql,@header=1
                    end
                end -- steps without log

            -- sp__job_status '%status%',@opt='log'
            declare cs cursor local for
                select output_file_name
                from #failures
                order by run_date desc,run_time desc,sid desc
            open cs
            while 1=1
                begin
                fetch next from cs into @logfile
                if @@fetch_status!=0 break

                if not isnull(@logfile,'')=''
                    begin
                    select @cmd='type "'+@logfile+'"'
                    truncate table #src
                    insert #src exec master..xp_cmdshell @cmd
                    update #src set line=
                        replace(replace(
                        replace(replace(
                            line,
                        '[SQLSTATE 01000]',''),'(Message 50000)',''),
                        '[SQLSTATE 42000]',''),'(Error 50000)','')

                    exec sp__printf ''
                    exec sp__prints @logfile
                    if @sel=1
                        exec('select line ['+@logfile+'] from #src order by lno')
                    else
                        exec sp__print_table '#src'
                    -- exec sp__select_astext 'select * from #src order by 1',@header=0
                    end -- print log

                end -- cursor cs
            close cs
            deallocate cs
            end -- print log

        end -- print failed step info

    end -- if there is history
else
    exec sp__printf '-- %s:no wrong step found for jobs %s in the lasts %d mins',
                    @proc,@jobs,@mins

dispose:
drop table #failures
drop table #src

goto ret

-- =================================================================== errors ==

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    print or send a report about jobs

Notes
    - can be added as last step of a job
    - %obj% can automatically detect running job
    - %obj% uses fn__config_app to get values for @smtp and @to

Parameters
    @jobs       filter jobs (job1|job2|...) (default is %)
    @steps      filter steps (step1|step2|...) (default is %)
    @mins       is the number of minutes before now to watch (default is -1)
                -1 means from last error, if last run was wrong
                1440 means last 24h
                2880 means last two days
    @excludes   filter jobs for exclusions (job1|job2|...)
    @attach     attach output files with message (default=1)
    @to         emails to sent report
                if null or empty will be searched:
                    1st in application config: SUPPORT_EMAIL
                    2nd in utility config: job_status.to
    @body       optional email message text
    @smtp       smtp server name or ip or
                if null or empty will be searched:
                    1st in application config: MAIL_SMTP_SERVER
                    2nd in utility config: job_status.smtp
                    3rd in utility config: smtp_server
    @ref        system or person reference for step
                in case of stored proc., the column last_upd report the date and name
                of last that has changed the code
    @opt        options
                log     show the txt of log
                sel     show results as select
                ok      show also not failed lines
                nep     do not apply continuous error prevention

Examples
    sp__job_status                                  -- show this help and jobs with failed steps

    sp__job_status "%status%"                       -- show info about jobs that contain "status"
                                                    -- and limited to last failure to now
    sp__job_status "%status%",@mins=2880            -- show info about jobs that contain "status"
                                                    -- of lasts two days
    sp__job_status "%status%",@opt="log"            -- show info about failed steps with logs (.txt)
    sp__job_status "%status%",@opt="ok|log"         -- show info about all steps of jobs (with .txt)
    sp__job_status "%",@opt="sel|ok|log"            -- show all steps as select
'
select
    job_failed as [job_failed(jf)],nsf,
    substring(convert(sysname,last_run),1,8) last_datef,
    substring(convert(sysname,last_run),9,6) last_timef
into #sp__job_status_list
from (
    select
        [name] as job_failed,
        (select count(*) from msdb..sysjobhistory h with (nolock)
         where h.job_id=j.job_id and h.run_status = 0 and h.sql_severity>0)
        as nsf,
        (select max(convert(bigint,h.run_date)*1000000+h.run_time) as last_run
         from msdb..sysjobhistory h with (nolock)
         where h.job_id=j.job_id and h.run_status = 0 and h.sql_severity>0)
        as last_run
    from msdb..sysjobs j with (nolock)
    ) j
where nsf>0
if @@rowcount>0
    select
        *,
        case when last_datef=convert(sysname,getdate(),112) then '*' else '' end
        as [@]
    from #sp__job_Status_list
    order by last_datef desc,last_timef desc
drop table #sp__job_status_list
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
end catch   -- sp__job_status