/*  leave this
    l:see LICENSE file
    g:utility,utijob
    v:131126\s.zaglio: near run not working
    v:121108\s.zaglio: better err_nosp and restyle
    v:121010\s.zaglio: added collate database_default
    v:121004\s.zaglio: noew correctly check emails separated by ; or , or |
    v:120613\s.zaglio: captured out of sp_update_job; and tests, see comments
    v:111130\s.zaglio: added @ref
    v:111118.1832\s.zaglio: expanded @job to multiple and added proc info and off option
    v:111110\s.zaglio: added output to #jobs
    v:110720.1638\s.zaglio: some imprecision in help, added warning
    v:110706\s.zaglio: added once schedule
    v:110610\s.zaglio: done and tested each case whoen in help
    r:110609\s.zaglio: reviewed @at parse
    r:110607\s.zaglio: reviewed @at parse
    v:110318\s.zaglio: added quiet
    v:110305\s.zaglio: a small bug near ena/dis job
    v:110212\s.zaglio: added macro %db%
    v:110130\s.zaglio: used sp_update_job to enable/disable jobs
    v:110119\s.zaglio: added DIS option to disable
    v:101222\s.zaglio: added multi schedule
    v:101221\s.zaglio: added multi schedule
    v:101204\s.zaglio: added log,dis,ena in @opt
    v:100919.1320\s.zaglio: better name for steps of sql statements and steps flow
    v:100919.1305\s.zaglio: added delete of log files and adapted to new version of sp__job_status
    v:100919.1225\s.zaglio: a bug in job of single step
    v:100919.1210\s.zaglio: added slot management
    v:100919\s.zaglio: a bug near job with same sp of diff. db
    v:100912\s.zaglio: added last run date/time
    v:100724.1100\s.zaglio: a remake
    t:msdb..sp_help_job  -- msdb.dbo.sp_get_composite_job_info
*/
CREATE proc [dbo].[sp__job]
    @job    sysname = null,
    @sp     nvarchar(4000) = null,
    @at     sysname = null,
    @emails nvarchar(1024) = null,
    @smtp   sysname = null,
    @ref    sysname = null,
    @opt    sysname = null,
    @dbg    int =0
as
begin
set nocount on
declare
    @proc sysname,@ret int,
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select @proc=object_name(@@procid),@ret=0
select @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @dbg=1 exec sp__printf '-- scope: %s',@proc

-- 120613\s.zaglio: rarely do not disable without errors
if @@trancount>0 goto err_trn

/*
-- drop table #xp_results
create table #xp_results(
    [job id] uniqueidentifier not null,
    [last run date] int not null,
    [last run time] int not null,
    next_run_date int not null,
    next_run_time int not null,
    next_run_schedule_id int not null,
    requested_to_run int not null, -- bool
    request_source int not null,
    request_source_id sysname collate database_default null,
    running int not null, -- bool
    current_step int not null,
    current_retry_attempt int not null,
    job_state int not null )

insert #xp_results
exec msdb..xp_sqlagent_enum_jobs
    @is_sysadmin = 1,
    @job_owner = ''
*/

select @job=replace(@job,'%db%',db_name())
select @job=replace(@job,'*','#')
select @job=replace(@job,'#','%')
if charindex('%',@job)>0
    select @job=replace(replace(@job,'_','[_]'),'''','''''')

select @sp =replace(@sp ,'*','#')

if @job is null
or (@job!='%'                       -- 120613\s.zaglio: a bug on list
    and charindex('%',@job)>0
    and @sp is null
    )
    goto help

select
    @emails=ltrim(rtrim(isnull(@emails,''))),
    @smtp=ltrim(rtrim(isnull(@smtp,'')))

if @emails!='' and @smtp=''
    select @smtp=ltrim(rtrim(convert(sysname,dbo.fn__config('smtp_server',null))))

if @emails!='' and @smtp='' goto err_logv

if @job='%' and @sp='#' goto err_cdaj

if @emails!='' and not dbo.fn__chk_email(@emails,';,|') is null goto err_wrem

-- ============================================================== declaration ==

if @dbg=-1 exec sp__printf '== declaration =='

declare
    @cmd_log nvarchar(4000),@n int,
    @jid uniqueidentifier,@sid int,@lid int,@schid int,
    @db sysname,@i int,@dt datetime,
    @freq_type int,@freq_interval int, @freq_subday_type int,
    @freq_subday_interval int,@freq_relative_interval int,
    @freq_recurrence_factor int, @start_date int,
    @end_date int, @start_time int,
    @end_time int,@at_msg sysname,
    @time int,@date int,
    @crlf nvarchar(2),@cmd nvarchar(4000),@step sysname,
    @ofa int,@osa int,@id int,
    @sql nvarchar(4000),
    @log nvarchar(512)

declare @cod table(cod char(3),val tinyint,typ tinyint)
    insert @cod
    /*
    -- month
    select 'jan',1  union
    select 'feb',2  union
    select 'mar',3  union
    select 'apr',4  union
    select 'may',5  union
    select 'jun',6  union
    select 'jul',7  union
    select 'aug',8  union
    select 'sep',9  union
    select 'oct',10 union
    select 'nov',11 union
    select 'dec',12 union
    */
    -- week day  -- print ascii('D')
    select 'sun',1  ,68 union
    select 'mon',2  ,68 union
    select 'tue',4  ,68 union
    select 'wed',8  ,68 union
    select 'thu',16 ,68 union
    select 'fri',32 ,68 union
    select 'sat',64 ,68 union
    -- special day -- print ascii('S')
    select 'eom',1  ,83 union  -- end of month
    select 'fom',2  ,83        -- 1st of month

declare
    -- select * from msdb..sysschedules
    @ranges table(
        id int identity primary key,

        token varchar(64),
        pos int,

        [start_date] int null,
        [end_date] int null,
        [start_time] int null default(0),
        [end_time] int null default (235959),

        interval int null default (0),
        freq_type int null default (0),
        freq_subday_type int null default (0),
        freq_interval int null default (0),
        freq_subday_interval int null default (0),
        freq_relative_interval int null default (0),
        freq_recurrence_factor int null default (0)
        ) -- @ranges

-- ============================================================== init =====

if @dbg=-1 exec sp__printf '== init =='

select @crlf=crlf from fn__sym()

select @i=charindex('|log:',@opt)
if @i>0 select @log=substring(@opt,@i+5,charindex('|',@opt,@i+5)-@i-5)
if @log='%temp%' select @log=null

if charindex('|sql|',@opt)>0
    select
        @db=db_name(),
        @cmd=@sp,
        @step=dbo.fn__hex(dbo.fn__crc32(@cmd))
else
    begin
    if @sp!='#'
        begin
        if @dbg=1 exec sp__printf 'checking if exists sp "%s"',@sp
        if object_id(@sp) is null goto err_nosp
        end
    select
        @db=isnull(parsename(@sp,3),db_name()),
        @cmd=parsename(@sp,1), -- become name of step
        @step=replace(replace(@db+'.'+@cmd,'.','_'),' ','_')
    end

-- search fors single job
select @n=count(*)
from msdb..sysjobs j
where j.name like @job

-- there is/are no jobs to delete
if @n=0 and @sp='#' goto ret

if @dbg=1 exec sp__printf 'found %d jobs',@n

if @n=1
    select @job=[name],@jid=job_id
    from msdb..sysjobs j
    where j.name like @job

if charindex('|ena|',@opt)>0 and not @jid is null
and @sp is null
    begin
    /*  this dont work...i don't know why
        update msdb.dbo.sysjobs set enabled = 1 where job_id=@jid */
    exec @ret=msdb.dbo.sp_update_job @job_id=@jid,@enabled=1

    -- 120613\s.zaglio: rarely do not disable without errors
    if 1!=(select enabled from msdb.dbo.sysjobs where job_id=@jid)
    or @ret!=0
        goto err_upj

    goto ret
    end

if charindex('|dis|',@opt)>0
and not @jid is null
and @sp is null
    begin
    /*  this dont work because sqlagent keep info in memory
        update msdb.dbo.sysjobs set enabled = 0 where job_id=@jid */
    exec @ret=msdb.dbo.sp_update_job @job_id=@jid,@enabled=0

    -- 120613\s.zaglio: rarely do not disable without errors
    if 0!=(select enabled from msdb.dbo.sysjobs where job_id=@jid)
    or @ret!=0
        goto err_upj

    goto ret
    end

select @sid=step_id
from msdb..sysjobsteps s
where s.job_id=@jid and [step_name]=@step

-- search if already exist a previous log step
select @lid=step_id,@cmd_log=command
from msdb..sysjobsteps s
where s.job_id=@jid and [step_name]=@proc+'_status'

if not @emails is null
    begin
    if '##' in (left(@smtp,2),right(@smtp,2))
        begin
        select @smtp=convert(sysname,dbo.fn__config(substring(@smtp,3,len(@smtp)-4),null))
        end
    else
        begin
        if '#' in (left(@smtp,1),right(@smtp,1))
            begin
            select @sql=N'select @smtp=convert(sysname,dbo.fn_config('''
                       +substring(@smtp,2,len(@smtp)-2)+''',null)'
            exec sp_executesql @sql,N'@smtp sysname out',@smtp=@smtp out
            end
        end

    if @smtp is null goto err_smtp

    select @cmd_log='sp__job_status @mins=-1,@jobs='''+@job+''''
               +',@to='''+@emails+''''+coalesce(',@smtp='''+@smtp+'''','')
               +isnull(',@ref='''+@ref+'''','')
               +',@opt='''
    if charindex('|sp4|',@opt)>0 select @cmd_log=@cmd_log+'sp4'
    if charindex('|sp8|',@opt)>0 select @cmd_log=@cmd_log+'|sp8'
    select @cmd_log=@cmd_log+''''
    end
else
    begin
    if @dbg>0 exec sp__printf 'Warning! Without @emails, the status step is omitted.'
    end


-- ================================================================ list jobs ==

if @dbg=-1 exec sp__printf '== list jobs =='

if charindex('%',@job)>0 and @sp is null
    begin
    select @cmd_log='
    select date_modified,[name],[enabled],date_created,version_number
    from msdb..sysjobs j with (nolock)
    where j.name like '''+@job+'''
    order by 1 desc,2 desc
    '
    exec sp__select_astext @cmd_log
    goto ret
    end -- list of jobs

-- ======================================================== list steps of job ==

if @dbg=-1 exec sp__printf '== list steps =='

if not @jid is null and @sp is null and @emails is null and @at is null
and charindex('|run|',@opt)=0
    begin
    --    sysjobactivity,sysjobhistory,sysjobs,sysjobschedules
    --    sysjobservers,sysjobsteps,sysjobs_view,sysjobstepslogs >=mssql2k8
    select @cmd_log='
    select
        s.step_id id,
        s.step_name,
            case
            when len(s.command)>40 then left(s.command,40)+''...''
            else s.command
            end
        as command,
        s.last_run_date,s.last_run_time,
        case s.last_run_outcome
        when 0 then ''not completed''
        when 1 then ''completed''
        when 2 then ''new try''
        when 3 then ''aborted''
        when 5 then ''unknown''
        end las_run_outcome,
        s.database_name,s.output_file_name
    from msdb..sysjobsteps s with (nolock)
    where s.job_id=''{1}''
    order by 1'
    exec sp__select_astext @cmd_log,@p1=@jid

    goto ret
    end -- list steps of job


-- ================================================== at parameter management ==

if @dbg=-1 exec sp__printf '== at parameter manag =='


-- ##########################
-- ##
-- ## parse schedule
-- ##
-- ########################################################
-- tech info at: http://msdn.microsoft.com/it-it/library/ms366342.aspx

if not @at is null
    begin
    if @dbg=2 exec sp__printf 'calculating schedule...'
    declare @tkn sysname,@tk1 sysname,@tk2 sysname,@tk3 sysname
    declare @ats table (pos int,tkn sysname,typ tinyint)
    insert  @ats(pos,tkn,typ)
    select  pos,token,
            case
            when left(token,1)='+'
            then 0                                  -- n minutes from now
            when patindex('%[:;]%',token)=0 and charindex('-',token)>0
            then 90                                 -- start date
            when patindex('%[;-]%',token)=0 and charindex(':',token)>0
            then 80                                 -- time
            when patindex('%[:;-]%',token)=0 and
                 (right(token,1) in ('w','d','h','n') or
                  token in (select cod from @cod))
            then 1                                  -- occurrencies
            when patindex('%[:;-]%',token)>0
            then 5                                  -- ranges
            when token='once'                       -- one time
            then 99
            end
    from dbo.fn__str_table(@at,'')

    -- adjust times & dates
    update @ats set
        tkn=convert(int,dbo.fn__str_at(tkn,':',1)*10000)
           +convert(int,dbo.fn__str_at(tkn,':',2)*100)
           +convert(int,isnull(dbo.fn__str_at(tkn,':',3),0))
    where typ=80
    update @ats set
        tkn=convert(int,dbo.fn__str_at(tkn,'-',1)*10000)
           +convert(int,dbo.fn__str_at(tkn,'-',2)*100)
           +convert(int,dbo.fn__str_at(tkn,'-',3))
    where typ=90

    -- test how many they are
    if (select count(*) from @ats where typ=80)>2
    or (select count(*) from @ats where typ=90)>2
        goto err_tmdt

    -- set 80,90 to 1st and 81,91 to second
    if (select count(*) from @ats where typ=80)=2
        update @ats set typ=81
        where typ=80
        and tkn= (select max(cast(tkn as int))
                    from @ats
                    where typ=80)

    if (select count(*) from @ats where typ=90)=2
        update @ats set typ=91
        where typ=90
        and tkn= (select max(cast(tkn as int))
                    from @ats
                    where typ=90)

    if @dbg=2 select * from @ats

    select @i=min(pos),@n=max(pos) from @ats

    select
        @freq_type=8,        -- the base is week
        @freq_interval=null, -- if null, all days
        @freq_subday_type=null,
        @freq_subday_interval=0,@freq_relative_interval=0,
        @freq_recurrence_factor=null, @at_msg='',
        @start_date=convert(int,convert(sysname,getdate(),112)),
        @end_date=99991231

    if exists(select top 1 null from @ats where typ=1)
        -- one range for all occurrencies
        insert @ranges(token,[start_date],start_time,end_time,end_date)
        select '*',@start_date,0,235959,@end_date

    -- scan schedule commands
    declare cs cursor local for
        select tkn,typ
        from @ats
        order by typ
    open cs
    while 1=1
        begin
        fetch next from cs into @tkn,@i
        if @@fetch_status!=0 break

        if @i=0     -- NN minutes from now
            insert  @ranges(token,start_time,freq_type,freq_interval,freq_subday_type)
            select  @at,
                    convert  (
                      int,
                      replace(
                        convert(
                          sysname,
                          dateadd(
                            s,convert(int,substring(@at,2,10)),
                            getdate()),
                          8),
                        ':','')
                    ),
                freq_time=1, freq_interval=0, freq_subday_type=1

        -- time range (hh:mm:ss-hh:mm:ss;step)
        if @i=5
            begin
            select
                @tk3=dbo.fn__str_at(@tkn,';',2),    -- step
                @tk2=dbo.fn__str_at(@tkn,';',1),    -- end
                @tk1=dbo.fn__str_at(@tk2,'-',1),    -- start
                @tk2=dbo.fn__str_at(@tk2,'-',2)
            -- exec sp__printf 'tk1:%s, tk2:%s, tk3:%s',@tk1,@tk2,@tk3
            if @tk3='' goto err_range

            if left(@tk3,1) like '[1-9]' and right(@tk3,1) in ('h','n')
                insert @ranges( token,interval,start_time,end_time,freq_type,
                                freq_subday_type,freq_subday_interval,
                                freq_interval)
                select
                    @tkn,
                    interval    =convert(int,left(@tk3,len(@tk3)-1)),
                    start_time  =convert(int,dbo.fn__str_at(@tk1,':',1)*10000)
                                +convert(int,dbo.fn__str_at(@tk1,':',2)*100)
                                +convert(int,isnull(dbo.fn__str_at(@tk1,':',3),0)),
                    end_time    =convert(int,dbo.fn__str_at(@tk2,':',1)*10000)
                                +convert(int,dbo.fn__str_at(@tk2,':',2)*100)
                                +convert(int,isnull(dbo.fn__str_at(@tk2,':',3),0)),
                    freq_type   =case right(@tk3,1)
                                 when 'h' then 4
                                 when 'n' then 4
                                 end,
                    freq_subday_type=case right(@tk3,1)
                                     when 'h' then 8
                                     when 'n' then 4
                                     end,
                    freq_subday_interval=left(@tk3,len(@tk3)-1),
                    freq_interval=1
            else
                goto err_range
            end -- time range

        if @i=1 -- occurrencies
            begin
            -- exec sp__job 'spj_test',@at='48w mon 10:30',@dbg=2
            -- exec sp__job 'spj_test',@at='1w Tue Wed 10:30',@dbg=2
            -- exec sp__job 'spj_test',@at='1w Tue Wed',@dbg=2

            -- select * from msdb..sysschedules
            select @tk1=right(@tkn,1),@tk2=substring(@tkn,1,len(@tkn)-1)

            if @tkn in (select cod from @cod where typ=68)
                select @freq_interval=@freq_interval|val
                from @cod
                where cod=@tkn and typ=68

            if @tkn='fom'
                select  @freq_type=32,@freq_interval=8,@freq_relative_interval=1,
                        @freq_subday_type=1

            if @tkn='eom'
                select  @freq_type=32,@freq_interval=8,@freq_relative_interval=16,
                        @freq_subday_type=1

            if @tk1='w' and isnumeric(@tk2)=1
                select @freq_recurrence_factor=@tk2,@freq_subday_type=1 -- specific hour

            if @tk1='h' and isnumeric(@tk2)=1
                select @freq_subday_type=8,@freq_subday_interval=@tk2

            if @tk1='n' and isnumeric(@tk2)=1
                select @freq_subday_type=4,@freq_subday_interval=@tk2

            update @ranges set
                freq_type=@freq_type,
                freq_interval=isnull(@freq_interval,1|2|4|8|16|32|64),
                freq_subday_type=@freq_subday_type,
                freq_subday_interval=@freq_subday_interval,
                freq_relative_interval=@freq_relative_interval,
                freq_recurrence_factor=@freq_recurrence_factor
            where token='*'
            end -- occurrencies

        -- set stard/end date/time
        if @i in (90,91,80,81)         -- if not exist at least one schedule...
        and not exists(select null from @ranges)
            insert @ranges(token,[start_date],start_time,end_time,end_date,
                           freq_type,freq_interval)
            select '*',@start_date,0,235959,@end_date,
                   4,1

        if @i=90 update @ranges set [start_date]=@tkn
        if @i=91 update @ranges set [end_date]=@tkn
        if @i=80 update @ranges set [start_time]=@tkn
        if @i=81 update @ranges set [end_time]=@tkn

        if @i=99 update @ranges set freq_type=1

        end -- while of cursor for ats
    close cs
    deallocate cs

    -- some last common adjustements
    update @ranges set
        freq_recurrence_factor=isnull(freq_recurrence_factor,1),
        freq_subday_Type=isnull(freq_subday_Type,1)

    if @dbg=2 select * from @ranges

    -- verify
    declare @schedule_description nvarchar(255)
    declare cs cursor local for
        select
            [start_date],end_date,start_time,end_time,
            freq_type,freq_subday_type,freq_interval,
            freq_subday_interval,freq_relative_interval,
            freq_recurrence_factor
        from @ranges
    open cs
    while 1=1
        begin
        fetch next from cs into
            @start_date,@end_date,@start_time,@end_time,
            @freq_type,@freq_subday_type,@freq_interval,
            @freq_subday_interval,@freq_relative_interval,
            @freq_recurrence_factor
        if @@fetch_status!=0 break

        select @schedule_description =''
        exec msdb..sp_get_schedule_description
          @freq_type=@freq_type,
          @freq_interval=@freq_interval,
          @freq_subday_type=@freq_subday_type,
          @freq_subday_interval=@freq_subday_interval,
          @freq_relative_interval=@freq_relative_interval,
          @freq_recurrence_factor=@freq_recurrence_factor,
          @active_start_date=@start_date,
          @active_end_date=@end_date,
          @active_start_time=@start_time,
          @active_end_time=@end_time,
          @schedule_description=@schedule_description out

        if @schedule_description is null or @dbg=2
            begin
            exec sp__printf '
            description             = %s
            freq_type               = %d
            freq_interval           = %d
            freq_subday_type        = %d
            freq_subday_interval    = %d
            active_start_date       = %d
            active_start_time       = %d
            active_end_date         = %d
            active_end_time         = %d
            freq_recurrence_fac     = %d'
            ,@schedule_description,
             @freq_type, @freq_interval, @freq_subday_type, @freq_subday_interval,
             @start_date, @start_time, @end_date, @end_time,
             @freq_recurrence_factor
            exec sp__printf '            freq_relative_interval  = %d',@freq_relative_interval
            if @schedule_description is null
                begin
                exec sp__printf '!! warning: null schedule description !!'
                select @at_msg=isnull(@at_msg,'generic')
                end
            end -- dbg
        end -- while of cursor
    close cs
    deallocate cs

    if @at_msg!='' goto err_csch

    end -- @at

-- ====================================================== begin job managment ==

if @dbg=-1 exec sp__printf '== begin job man =='

begin tran

if @sp='#'
    begin
    -- delete msg must be visible from user
    exec sp__printf 'deleting job/s(%s)...',@job
    -- delete job
    while (1=1)
        begin
        select @jid=null
        select top 1 @jid=job_id
        from msdb..sysjobs j
        where j.name like @job
        if @jid is null break
        exec sp__printf '    deleting job/s(%s)...',@jid

        -- step into steps and delete log files if exists

        declare cs cursor local for
            select output_file_name
            from msdb..sysjobsteps s
            where job_id=@jid
            and not output_file_name is null
        open cs
        while 1=1
            begin
            fetch next from cs into @log
            if @@fetch_status!=0 break
            exec sp__printf '      deleting log (%s)...',@log
            select @cmd='del /q "'+@log+'"'
            exec master..xp_cmdshell @cmd,no_output
            end -- while of cursor
        close cs
        deallocate cs

        exec @ret=msdb..sp_delete_job @job_id=@jid
        if @@error!=0 or @ret!=0 goto err_jdel
        end -- while

    if @sp='#' goto ret
    select @jid=null,@sid=null,@lid=null
    end

-- no error if delete a job that not exists (but no msg is outed)
if @jid is null and @sp='#' goto ret

if @jid is null and @sp is null
and @at is null and @emails is null
    goto err_njob

-- if @sp is null and @sid is null and @sp is null
-- and not @at is null  -- change at

-- ============================================================= change email ==

if @dbg=-1 exec sp__printf '== chg email =='

if charindex('|run|',@opt)=0 and @sp is null and @sid is null
and not @emails is null
    begin
    if @jid is null goto err_njob
    if @dbg=1 exec sp__printf 'updating emails...'
    exec msdb..sp_update_jobstep
        @job_id=@jid,@step_id=@lid,
        @command=@cmd_log
    end -- chg email

-- ====================================================== create update steps ==

if @dbg=-1 exec sp__printf '== create upd steps =='

if not @sp is null
    begin

    -- create job if not exists or drop if exists same step name

    if @jid is null
        begin
        if @dbg=1 exec sp__printf 'add new job "%s" on server "(local)"',@job
        exec msdb..sp_add_job @job_name = @job, @job_id=@jid out
        exec msdb..sp_add_jobserver @job_id=@jid,  @server_name='(local)'
        end

    if @jid is null goto err_njob

    -- ============================================================ log file name ==

    if @dbg=-1 exec sp__printf '== log file name =='

    if charindex('|nolog|',@opt)=0
        begin
        if @log is null exec sp__get_temp_dir @log out
        if right(@log,1)!='\' select @log=@log+'\'
        select @log=@log+@step+'_log.txt'
        end

    if not @lid is null
        begin
        if @dbg=1 exec sp__printf 'deleting log step (%d)...',@lid
        exec @ret=msdb..sp_delete_jobstep @job_id=@jid,@step_id=@lid
        if @@error!=0 or @ret!=0 goto ret
        end

    -- ================================================================= add step ==

    if @dbg=-1 exec sp__printf '== add step =='

    if charindex('|elapsed|',@opt)>0
        select @cmd ='declare @d datetime,@ms int'+@crlf
                    +'exec sp__elapsed @d out'+@crlf
                    +'exec '+quotename(@sp)+@crlf
                    +'exec sp__elapsed @d,@ms=@ms out'+@crlf
                    +'exec sp__log '''+@sp+''',@n=@ms'

    if @sid is null
        begin
        if @dbg=1 exec sp__printf 'add step "%s" on db "%s"...',@step,@db
        exec @ret=msdb..sp_add_jobstep
            @job_id = @jid,
            @step_name = @step,
            -- @step_id = @lid,        -- insert before last
            @subsystem = 'tsql',
            @command = @cmd,
            @database_name=@db,
            @on_success_action=1,   -- for single job of single step
            @on_fail_action=2,
            @output_file_name=@log,
            @flags=0                -- overwrite log
           --@retry_attempts = 5,
           --@retry_interval = 5
        end
    else
        begin
        if @dbg=1 exec sp__printf 'update step "%s"...',@step
        exec @ret=msdb..sp_update_jobstep
            @job_id = @jid,
            @step_id = @sid,        -- replace
            @subsystem = 'tsql',
            @command = @cmd,
            @database_name=@db,
            @on_success_action=3,   -- next step
            @on_fail_action=3,
            @output_file_name=@log,
            @flags=0                -- overwrite log
           --@retry_attempts = 5,
           --@retry_interval = 5
        end

    if @@error!=0 or @ret!=0 goto err_step

    -- ========================================================= re-add log error ==

    if @dbg=-1 exec sp__printf '== re-add log =='

    select @lid=null
    if not @cmd_log is null
        begin
        exec @ret=msdb..sp_add_jobstep @job_id = @jid,
            @step_name = 'sp__job_status',
            @subsystem = 'tsql',
            @command = @cmd_log,
            @database_name=@db
        if @@error!=0 or @ret!=0 goto err_logs

        -- adjust non log steps
        select @lid=null
        select @lid=step_id
        from msdb..sysjobsteps s
        where s.job_id=@jid and [step_name]='sp__job_status'

        if @dbg=1 exec sp__printf '-- added log step with step id=%d',@lid

        end  -- log

    /*  examples
    step    if_ok     if_err  if_err_ras    if_nolog
    1       next      log     next          end
    2       next      log     next          end
    3       next/end  log     next          end
    log     end       end     end            -
    */

    if @dbg=1 exec sp__printf '-- align gotos of steps'
    select @i=1,@id=max(step_id) from msdb..sysjobsteps s where s.job_id=@jid

    select @osa=3   -- next
    if charindex('|ras|',@opt)>0 select @ofa=3  -- next
    else select @ofa=case when @lid is null then 2 else 4 end -- goto

    while (@i<=@id)
        begin
        if @i=@id select @osa=1,@ofa=2
        if @dbg=1 exec sp__printf '-- step_id @i=%d, @osa=%d, @ofa=%d, @lid=%d (1=end ok;2=end ko;3=next;4=goto)',@i,@osa,@ofa,@lid
        exec @ret=msdb..sp_update_jobstep
            @job_id=@jid,@step_id=@i,
            @on_success_action  =@osa,
            @on_fail_action     =@ofa,
            @on_fail_step_id    =@lid
        select @i=@i+1
        end -- while
    -- if @dbg=1 select * from msdb..sysjobsteps where job_id=@jid

    end -- add/chg steps

-- ================================================== run/add/change schedule ==

if @dbg=-1 exec sp__printf '== add/change schedule =='

if charindex('|dis|',@opt)>0
    begin
    exec sp__printf 'disabling job %s',@jid
    exec @ret=msdb.dbo.sp_update_job @job_id=@jid,@enabled=0
    -- 120613\s.zaglio: rarely do not disable without errors
    if 0!=(select enabled from msdb.dbo.sysjobs where job_id=@jid)
    or @ret!=0
        goto err_upj
    end


-- ##########################
-- ##
-- ## set schedule
-- ##
-- ########################################################

if not @at is null
    begin
    if @jid is null goto err_njob
    declare cs cursor local for
        select [name]
        -- select *
        from msdb..sysjobschedules j1       -- prob not compatible with mssql2k
        join msdb..sysschedules j2
        on j1.schedule_id=j2.schedule_id
        where job_id=@jid
    open cs
    while 1=1
        begin
        fetch next from cs into @tkn
        if @@fetch_status!=0 break
        if @dbg=1 exec sp__printf 'deleting schedule (%s) for update',@tkn
        exec @ret=msdb..sp_delete_jobschedule @job_id=@jid,@name=@tkn
        end -- delete schedules
    close cs
    deallocate cs

    -- readd schedules
    declare cs cursor local for
        select
            id,start_date,end_date,start_time,end_time,
            freq_type,freq_subday_type,freq_interval,
            freq_subday_interval,freq_relative_interval,
            freq_recurrence_factor
        from @ranges
    open cs
    while 1=1
        begin
        fetch next from cs into
            @schid,@start_date,@end_date,@start_time,@end_time,
            @freq_type,@freq_subday_type,@freq_interval,
            @freq_subday_interval,@freq_relative_interval,
            @freq_recurrence_factor
        if @@fetch_status!=0 break

        select @tkn=@job+'('+convert(sysname,@schid)+')'
        if @dbg=1 exec sp__printf 'adding schedule "%s"',@tkn
        exec @ret=msdb..sp_add_jobschedule
            @name = @tkn,
            @job_id = @jid,
            @enabled = 1,
            @freq_type = @freq_type,
            @freq_interval = @freq_interval,
            @freq_subday_type = @freq_subday_type,
            @freq_subday_interval = @freq_subday_interval,
            @freq_relative_interval = @freq_relative_interval,
            @freq_recurrence_factor = @freq_recurrence_factor,
            @active_start_time = @start_time,
            @active_start_date = @start_date,
            @active_end_time = @end_time,
            @active_end_date = @end_date
        end -- while add schedule
    close cs
    deallocate cs

    end -- schedule

goto ret

-- =================================================================== errors ==
err:exec @ret=sp__err @e_msg,@proc,@p1=@e_p1                            goto ret
err_njob:select @e_msg='no job found or created'                        goto err
err_aani:select @e_msg='at changes not implemented again'               goto err
err_eani:select @e_msg='email changes not implemented again'            goto err
err_nsql:select @e_msg='SQL option not implemented again'               goto err
err_nosp:select @e_msg='stored proc. %s not found',@e_p1=@sp            goto err
err_step:select @e_msg='creating step'                                  goto err
err_logs:select @e_msg='creating log step'                              goto err
err_wrem:select @e_msg='wrong email (%s)',@e_p1=@emails                 goto err
err_csch:select @e_msg='calculating schedule:%s',@e_p1=@at_msg          goto err
err_jdel:select @e_msg='deleting jobs'                                  goto err
err_cdaj:select @e_msg='cannot delete all jobs'                         goto err
err_smtp:select @e_msg='smtp server not specified'                      goto err
err_logv:select @e_msg='smtp or emails empty'                           goto err
err_range:select @e_msg='missing or wrong step in range'                goto err
err_tmdt:select @e_msg='too mach times or dates'                        goto err
err_trn:select @e_msg='this sp cannot be executed into a transaction'   goto err

err_upj:
/*  not necessary because hope that sp_update_job shown its errors
    exec @ret=sp__err 'sp_update_job failed',@proc
*/
goto ret

-- ===================================================================== help ==

help:
--     month                   jan,feb,mar,apr,may,jun,jul,aug,sep,oct,nov,dec (only one)
exec sp__usage @proc,'
Scope
    create and maintain jobs with log and error management

Parameters
    #jobs   optional table where store running jobs
    @job    is the name of job to manage;
            accept # as wild char and multiple roots
            separated by pipe ("|")
    @sp     is the name of stored that the step call
            (if already exists, will be replaced with new info)
            if is "#", the job will be deleted
    @at     time of execution (see below)
    @email  emails wich send the log in case of failure of job
            Use "ras" to run all steps before send the lists
            of failed
    @ref    is a generic text passed directly to sp__job_status
    @opt    options
    @dbg    2 show a more detailed schedule description

Options
    ras      continue to next step if current fail
    log:path alternative path for output file (by default a %temp%\@db@proc_log.txt file is created)
    nolog    do not output to file
    elapsed  enable tracing of executions with sp__log
    sql      consider @sp as a generic sql
    run      start the job immediatelly
    quiet    do not show msg about run of job (succesfull...errors..etc)
    sp4      send one email every 4h even if the jub fail every 5 minutes
    sp8      send one email every 8h
    dis      disable the job (also immediatelly, see exampe)
    ena      enabled the job (also immediatelly, see exampe)
    off      print scripts to disable and re-enable active jobs

Time expressions
    yyyy-mm-dd              start date
    hh:nn:ss                every day at hh:nn if start date unspecified
    ??w                     every ?? weeks
    ??h                     every ?? hours
    ??n                     every ?? minutes
    day                     Mon Tue Wed Thu Fri Sat Sun (multiple option)
    +NNNNN                  start after NN seconds
    hh:mm-hh:mm;step        interval; step can be every ?h, ?m, ?d, ?n (see above)
    fom                     1st of month
    eom                     end of month
    once                    execute only one time

Optional output table for running jobs (returned by master..xp_sqlagent_enum_jobs)
    create table #jobs(
        id int   identity,
        [server] sysname,
        [name]   sysname,
        [description]   nvarchar(512),
        job_id          uniqueidentifier,
        last_run_date   int,
        last_run_time   int,
        -- process info
        spid    int null,
        [from]  nvarchar(32) null,
        [sql]   nvarchar(256) null
        )

Examples:

    -- help and list of running jobs
    sp__job

    -- list of jobs
    sp__job #       -- or ''*''

    -- list of job by root
    sp__job myj#

    -- add 1st step (and create the job) and the second
    sp__job ''my job'',''sp_test''
    sp__job ''my job'',''sp_test1''

    -- list steps
    sp__job ''my job''

    -- delete job
    sp__job ''my_job'',#

    -- add sql step
    sp__job ''my_job'',''sp__log #my_job'',@opt=''sql''

    -- add/chg error control and email to wich send log
    sp__job ''my_job'',@email=''fname.lname@mails.org''

    -- add/chg schedule
    sp__job ''my_job'',@at=''10:30''            -- every day at 10:30
    sp__job ''my_job'',@at=''10:30-20:30;5h''   -- start at 10:30 end at 20:30 every 5 hours
                                                -- multi time
    sp__job ''my_job'',@at=''00:00-08:00;2h 08:00-21:00;20n 21:00-23:59;2h''
    sp__job ''my_job'',@at=''Tue''              -- every Tuesday at midnight
    sp__job ''my_job'',@at=''Sat Sun 10:30''    -- every weekend at 10:30
    sp__job ''my_job'',@at=''Sat Sun 8:00 21:00 20n''    -- vertical range
    sp__job ''my_job'',@at=''5n''               -- every five minutes from midnight

    sp__job ''my_job'',@at=''48w mon 10:30''    -- every 1st monday in december
                                              -- at 10:30

    sp__job ''my_job'',@at=''fom 10:30''         -- every 1st of month at 10:30
    sp__job ''my_job'',@at=''eom 10:30''         -- every end of month at 10:30

    sp__job ''my_job'',@at=''+5''            -- start 5 minutes from now

    sp__job ''my_job'',@at=''2011-07-14 20:20'' -- start the 14 jul, every day at 20:20
    sp__job ''my_job'',@at=''2011-07-14 20:20 once'' -- start the 14 jul, only one time at 20:20

    -- delete a job
    sp__job ''my_job'',#

    -- delete my jobs
    sp__job ''my#'',#

    -- disable a job
    sp__job ''my job'',@opt=''dis''

    -- print script to turn off and on active jobs (excluding disabled)
    sp__job ''myjobs1#|myjobs2#'',@opt=''off''

'
-- list running
-- declare @cmd_log nvarchar(4000),@name sysname,@n int,@ret int

if object_id('tempdb..#jobs') is null
    create table #jobs(
        id int identity,
        [server] sysname,
        [name] sysname,
        [description] nvarchar(512),
        job_id uniqueidentifier,
        last_run_date int,
        last_run_time int,
        -- process info
        spid int null,
        [from] nvarchar(32) null,
        [sql] nvarchar(256) null
        )

declare @filter table(job sysname)
insert @filter select token from fn__str_table(@job,'|')

select @sql=replace('
    select * into #xp_results -- select *
    from openrowset(
        "sqloledb",
        "server='+@@servername+';trusted_connection=yes",
        "set fmtonly off
         exec msdb..xp_sqlagent_enum_jobs @is_sysadmin = 1, @job_owner = """"
        ")',
    '"',
    '''')

select @sql=@sql+'
    insert #jobs(
        [server],
        [name],
        [description],
        job_id,
        last_run_date,
        last_run_time
        )
'
-- select top 1 * from msdb..sysjobs
if dbo.fn__isMSSQL2K()=1
    select @sql=@sql+'
    select top 100 percent
        j.originating_server,
        j.name,
        j.description,
        j.job_id,
        r.[last run date] as start_date,
        r.[last run time] as start_time
    from #xp_results r join msdb..sysjobs j with (nolock) on r.[job id]=j.job_id
    where r.running = 1
    order by 1,2'
else
    select @sql=@sql+'
    select top 100 percent
        s.srvname originating_server,
        j.name running_job_name,
        j.description,
        j.job_id,
        r.[last run date] as start_date,
        r.[last run time] as start_time
    from #xp_results r join msdb..sysjobs j on r.[job id]=j.job_id
    join master..sysservers s with (nolock) on s.srvid=j.originating_server_id
    where r.running = 1
    order by 1,2'

if @dbg=1 exec sp__printsql @sql
exec(@sql)
if @@error!=0 exec sp__printsql @sql

if not @job is null
    delete from #jobs
    where not id in (
        select id
        from #jobs j
        join @filter f
        on j.[name] like f.job
        )

update #jobs set
    spid=procs.spid,
    [from]=procs.batch_duration,
    [sql]=left(procs.sql,256)
from #jobs
join (
    select
        p.spid
    ,   right(convert(varchar,
                dateadd(ms, datediff(ms, p.last_batch, getdate()), '1900-01-01'),
                121), 12) as 'batch_duration'
    ,   case
                when p.program_name like 'sqlagent - tsql jobstep (job %'
                then (
                    select top 1 j.name
                    from msdb..sysjobs j
                    where
                        rtrim(ltrim(dbo.fn__str_between(p.program_name,'job ',' :',default)))
                        =
                        dbo.fn__hex(convert(varbinary,job_id))
                    )
                else object_name((select top 1 objectid from ::fn_get_sql(p.sql_handle)))
            end
        as obj
    ,   case
                when p.program_name like 'sqlagent - tsql jobstep (job %'
                then (
                    select top 1 j.job_id
                    from msdb..sysjobs j
                    where
                        rtrim(ltrim(dbo.fn__str_between(p.program_name,'job ',' :',default)))
                        =
                        dbo.fn__hex(convert(varbinary,job_id))
                    )
                else null
            end
        as job_id
    ,   p.hostname
    ,   p.loginame
    ,   substring((select top 1 text from ::fn_get_sql(p.sql_handle)),
                coalesce(nullif(case p.stmt_start when 0 then 0 else p.stmt_start / 2 end, 0), 1),
                case (case p.stmt_end when -1 then -1 else p.stmt_end / 2 end)
                    when -1
                            then datalength((select top 1 text from ::fn_get_sql(p.sql_handle)))
                    else
                            ((case p.stmt_end when -1 then -1 else p.stmt_end / 2 end) -
                             (case p.stmt_start when 0 then 0 else p.stmt_start / 2 end)
                            )
                    end
        ) as [sql]
    from master.dbo.sysprocesses p
    where p.spid!=@@spid
    and p.spid > 50
    and      p.status not in ('background', 'sleeping')
    and      p.cmd not in ('awaiting command'
                        ,'mirror handler'
                        ,'lazy writer'
                        ,'checkpoint sleep'
                        ,'ra manager')
    and p.sql_handle!=0x0
    -- order by batch_duration desc
    ) procs
on procs.job_id=#jobs.job_id

select * from #jobs order by id

if charindex('|off|',@opt)>0
    select
        'update msdb..sysjobs set [enabled]='+switch+' where job_id='''+
        convert(varchar(64),j.job_id)+''' -- '+j.[name]+' ('+[description]+')'
    from (select '0' switch union select '1' switch) switches,
        (
        select j.*
        from msdb..sysjobs j
        join @filter f
        on j.[name] collate database_default like f.job collate database_default
        where [enabled]=1
        ) j
    order by switch,j.name

set @ret=-1

goto ret

-- ===================================================================== exit ==
ret:
if @@trancount>0
    if @ret=0 commit else rollback

if @ret=0 and charindex('|run|',@opt)>0
    begin
    if charindex('|quiet|',@opt)=0
        exec msdb..sp_start_job @job_id = @jid
    else
        -- unfortunatelly is not possible manage error 22022
        -- even if the running job are checked
        exec msdb..sp_start_job
            @job_id = @jid,
            @output_flag =0
    end -- run

return @ret
end -- sp__job #