/*  leave this
    l:see LICENSE file
    g:utility
    v:090504\S.Zaglio: from http://www.sqlservercentral.com/scripts/Miscellaneous/30124/
    t: to study and integrate into sp__job
*/
CREATE PROCEDURE [sp__job_wait]
    @jobs nvarchar(2000),
    @is_running bit = 0,
    @max_seconds int = 10,
    @pause_seconds int = null,
    @retrying_equals_running bit = 0
AS
/*
    Procedure waits until the indicated job or jobs, have the status of running or stopped.
    It will wait until it has reached the max wait time, checking the status every 5 seconds.

    It returns the results of the job.

     1 - successfull
     2 - retrying
     3 - cancelled
    -1 - not started
    -2 - executing
     0 - failed
*/
declare
    @job nvarchar(50),
    @b int,
    @e int,
    @running int,
    @result int,
    @tries int,
      @is_sysadmin INT,
    @job_owner   sysname,
    @pause_string nvarchar(9),
    @pause_number int,
    @max_tries int,

    @last_run_date int,
    @last_run_time int,
    @run_date int,
    @run_time int,

    @minutes int,
    @hours int,
    @seconds int
begin

    set nocount on

    set @jobs = rtrim(ltrim(@jobs))

    if right(@jobs,1)<>','
    begin
        set @jobs = @jobs + ','
    end

    -- create temp tables
    create table #wait_job_status (
        job_id uniqueidentifier not null,
        last_run_date int not null,
        last_run_time int not null,
        next_run_date int not null,
        next_run_time int not null,
        next_run_schedule_id int not null,
        requested_to_run int not null, -- BOOL
        request_source int not null,
        request_source_id sysname null,
        running int not null, -- BOOL
        current_step int not null,
        current_retry_attempt int not null,
        job_state int not null
    )

    create table #wait_job_list (
        [name] nvarchar(100) not null primary key
    )

    -- set variables for status
    set @is_sysadmin = ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0)
    set @job_owner = SUSER_SNAME()

    if isnull(@pause_seconds,0)<1
    begin
        set @pause_number = floor(@max_seconds / (case when @max_seconds>30 then 4 else 2 end))
        set @pause_number = case when @pause_number > 15 then 15 when @pause_number < 1 then 1 else @pause_number end
    end
    else
    begin
        set @pause_number = @pause_seconds
    end

    select
        @hours = floor(@pause_number / 3600),
        @minutes = floor((@pause_number - (@hours * 3600)) / 60),
        @seconds = (@pause_number - (@hours * 3600) - (@minutes * 60)),
        @pause_string = right('00'+convert(nvarchar,@hours),2)+':'+
                        right('00'+convert(nvarchar,@minutes),2)+':'+
                        right('00'+convert(nvarchar,@seconds),2)

    set @max_tries = @max_seconds / @pause_number

    set @b = 0
    set @e = CHARINDEX(',',@jobs,@b+1)

    while (@e>0)
    begin
        set @job = SUBSTRING(@jobs,@b+1,@e-(@b+1))

        insert into #wait_job_list([name]) values(lower(ltrim(rtrim(@job))))

        set @b = @e
        set @e = CHARINDEX(',',@jobs,@b+1)
    end

    -- begin status check
    set @running = case when @is_running=1 then 0 else 1 end
    set @tries = 0
    set @last_run_date=0
    set @last_run_time=0
    set @run_date=0
    set @run_time=0

    while @running= case
                    when @is_running=1 then 0
                    else 1 end
          and @tries<=@max_tries and (@last_run_date=@run_date)
          and (@last_run_time=@run_time)
    begin
        set @running = @is_running
        set @tries = @tries + 1
        set @result = 0

        truncate table #wait_job_status

        insert into #wait_job_status
        exec master..xp_sqlagent_enum_jobs @is_sysadmin, @job_owner

        select
            @running = case when @is_running = 1 then 0 else 1 end,
            @last_run_date = case when @tries=1 then x.last_run_date else @last_run_date end,
            @last_run_time = case when @tries=1 then x.last_run_time else @last_run_time end,
            @run_date = x.last_run_date,
            @run_time = x.last_run_time
        from
            #wait_job_status x
        inner join
            msdb..sysjobs s
        on
            x.job_id=s.job_id
        left join
            msdb..sysjobhistory h
        on
            h.job_id=x.job_id and h.step_id=0 and h.run_date=x.last_run_date and h.run_time=x.last_run_time
        where
            lower(s.[name]) in (select [name] from #wait_job_list) and
            case when
            (@is_running=1 and (x.[running]<1 or (x.[running]>0 and x.[job_state]<>1 and @retrying_equals_running=0))) or
            (@is_running=0 and x.[running]>0 and (x.[job_state]=1 or @retrying_equals_running=1))
            then 1 else 0 end = 1

        if (@running=case when @is_running=1 then 0 else 1 end) and (@last_run_date=@run_date) and (@last_run_time=@run_time)
        begin
            -- job (or jobs) are not in correct state, so wait - then try again
            waitfor delay @pause_string
        end
        else
        begin
            -- job is in correct state, so pull status
            select
                @result = case when x.[job_state]<>1 and x.[running]=1 then 2 else h.[run_status] end
            from
                #wait_job_status x
            inner join
                msdb..sysjobs s
            on
                x.job_id=s.job_id
            left join
                msdb..sysjobhistory h
            on
                h.job_id=x.job_id and h.step_id=0 and h.run_date=x.last_run_date and h.run_time=x.last_run_time
            where
                lower(s.[name]) in (select [name] from #wait_job_list)
            order by
                case h.[run_status]
                    when 3 then 2
                    when 1 then 3
                    else 1 end desc
        end
    end

    if @tries>@max_tries
    begin
        select @result = case when @is_running=1 then -1
            else -2 end
    end

    -- drop temp tables
    drop table #wait_job_status
    drop table #wait_job_list

    -- return results
    return @result

end