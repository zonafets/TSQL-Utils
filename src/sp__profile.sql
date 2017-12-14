/*  leave this
    l:see LICENSE file
    g:utility
    d:130630\s.zaglio: sp__util_profile
    v:130630\s.zaglio: refactor
    v:101130\s.zaglio: Self adjusting trace to capture worst performing TSQL
    c:http://sqlserverperformance.idera.com/tsql-optimization/finding-heaviest-tsql-optimize-sql-server/
    t:sp__profile 2,@dbg=1
    t:xp_cmdshell 'dir f:\sqldata\*.*'
*/
CREATE proc sp__profile
    @MaxTraceTimeInMinutes smallint = null,
    @MinTraceTimeInMinutes smallint = null,
    @dbg smallint = 0
as
begin
set nocount on
declare @proc sysname, @ret int
select @proc=object_name(@@procid),@ret=0

if nullif(@MaxTraceTimeInMinutes,0) is null goto help

select @MinTraceTimeInMinutes=isnull(@MinTraceTimeInMinutes,
                                     @MaxTraceTimeInMinutes*0.75)

exec sp__printf 'Will run for %d minutes, please do not stop',
                @MaxTraceTimeInMinutes

set transaction isolation level read uncommitted
set lock_timeout 20000
set implicit_transactions off
if @@trancount > 0
        commit transaction
set language us_english
set cursor_close_on_commit off
set query_governor_cost_limit 0
set numeric_roundabort off

declare @spid int, @databaseid int, @applicationname nvarchar(256),
        @tridl int, @trids int,
        @trstatusl int, @trstatuss int,
        @tracepathl nvarchar(1024), @tracepaths nvarchar(1024),
        @tracetablelong nvarchar(1024), @tracetableshort nvarchar(1024),
        @currentduration bigint, @oldduration bigint,
        @tracerowsfound int, @maxtracefilesize bigint,
        @laststmtendtime datetime, @lastsampletime datetime,
        @laststmtendtimes datetime, @lastsampletimes datetime,
        @secsincelastcollection int, @bypasscollection bit,
        @shorttraceexists bit, @estimated bit, @bitone bit,
        @gatherwaittimeinsecs tinyint,
        @nooftsqlstmtsperminhighwater int, @nooftsqlstmtsperminlowwater int,
        @mindurationforlongtrace bigint, @mindurationforshorttrace bigint,
        @starttracetime datetime, @uniquetsql int,
        @statisticaldeviation dec(14,4), @statisticallastaverageduration bigint,
        @statisticalaverageduration bigint, @statisticalsamplesize int, @statisticalminimumpopulation int,
        @execstring varchar(50),
        @textdata nvarchar(4000),
        @duration bigint, @endtime datetime,
        @reads bigint, @writes bigint, @cpu int,
        @entrydatebucket int, @multiplierthisrow int, @multiplier int,
        @position int, @asciiposition int,
        @tsqlhashcode bigint,
        @multilineskip tinyint, @singlelineskip tinyint,
        @twocharacter char(2), @onecharacterascii int,
        @previoushighduration bigint

select @spid = @@spid,
        @currentduration = 5000000,
        @maxtracefilesize = 25, -- in mb
        @nooftsqlstmtsperminhighwater = 500, --- (per minute) this number for testing, normally would be perhaps 200
        @nooftsqlstmtsperminlowwater = 150, --- (per minute) this number for testing, normally would be perhaps 30
        @mindurationforlongtrace = 80000, -- overlap point between high and low traces (in microseconds)
        @mindurationforshorttrace = 1, -- in minutes
        @starttracetime = getdate(),
        @uniquetsql = 0,
        @statisticaldeviation = 100,
        @statisticalsamplesize = 30,
        @statisticalminimumpopulation = 300,
        @bitone = 1

--the io path to tempdb on high-end systems will be san, hence we should put the trace data files there too rather than on a local drive
-- use tempdb
select @tracepathl = left(physical_name, len(physical_name) -
charindex('\',reverse(physical_name))) + '\'
        from sys.database_files
        where file_id = 1
select @tracepaths = @tracepathl + 'heaviestshorttrace'
select @tracepathl = @tracepathl + 'heaviestlongtrace'

if @dbg>1
    begin
    -- exec sp_trace_setstatus 2, 0 -- stop trace
    -- exec sp_trace_setstatus 3, 2 -- close trace
    select 'exec sp_trace_setstatus '+convert(nvarchar(2),traceid)+', 2 -- close the long trace' sql,*
    -- select *
    from sys.fn_trace_getinfo(0)
    where property = 2 and convert(nvarchar(1024),value) like '%\heaviest%trace%'
    select [name] from tempdb..sysobjects where [name] like '##%'
    end

gather:

exec sp__printf '%t gathering...','%t'

select @bypasscollection = 0,
        @laststmtendtime  = getdate(),
        @lastsampletime = getdate(),
        @laststmtendtimes = getdate(),
        @lastsampletimes = getdate(),
        @gatherwaittimeinsecs = 30

if @dbg>1
    select traceid,value,@tracepaths tps,@tracepathl tpl
    from sys.fn_trace_getinfo(0)
    where property=2

select @trids = traceid
        from sys.fn_trace_getinfo(0)
        where property = 2 and convert(nvarchar(1024),value) like @tracepaths+'%'
if @@rowcount <> 0
        select @shorttraceexists = 1
else
        select @shorttraceexists = 0

select @tridl = traceid
-- select *
        from sys.fn_trace_getinfo(0)
        where property = 2 and convert(nvarchar(1024),value) like @tracepathl+'%'
if @@rowcount <> 0
        goto longtraceexists

createlongtrace:


select @bypasscollection = 1

if @dbg=1
    begin
    if @tridl is null exec sp__printf '+--creating long trace'
    else exec sp__printf '+--reopening long trace'
    end
exec sp_trace_create @tridl output, 2, @tracepathl, @maxtracefilesize, null, 10
if @dbg=1 exec sp__printf '  +--long trace %d in %s',@tridl,@tracepathl
if @shorttraceexists = 0
    begin
    if @dbg=1
        begin
        if @tridl is null exec sp__printf '+--creating short trace'
        else exec sp__printf '+--reopening short trace'
        end
    exec sp_trace_create @trids output, 2, @tracepaths, @maxtracefilesize, null, 10
    if @dbg=1 exec sp__printf '  +--short trace %d in %s',@trids,@tracepaths
    end



--select trace columns to show for completed statements on long trace
exec sp_trace_setevent @tridl, 41, 1, @bitone -- textdata
exec sp_trace_setevent @tridl, 41, 3, @bitone -- dbid
exec sp_trace_setevent @tridl, 41, 10, @bitone -- applicationname
exec sp_trace_setevent @tridl, 41, 12, @bitone --spid
exec sp_trace_setevent @tridl, 41, 13, @bitone -- duration in microseconds
exec sp_trace_setevent @tridl, 41, 15, @bitone -- endtime
exec sp_trace_setevent @tridl, 41, 16, @bitone --diskreadslogical
exec sp_trace_setevent @tridl, 41, 17, @bitone --diskwritesphysical
exec sp_trace_setevent @tridl, 41, 18, @bitone --cpu time

--select trace columns to show for completed sp statements on long trace
exec sp_trace_setevent @tridl, 45, 1, @bitone -- textdata
exec sp_trace_setevent @tridl, 45, 3, @bitone -- dbid
exec sp_trace_setevent @tridl, 45, 10, @bitone -- applicationname
exec sp_trace_setevent @tridl, 45, 12, @bitone --spid
exec sp_trace_setevent @tridl, 45, 13, @bitone -- duration in microseconds
exec sp_trace_setevent @tridl, 45, 15, @bitone -- endtime
exec sp_trace_setevent @tridl, 45, 16, @bitone --diskreadslogical
exec sp_trace_setevent @tridl, 45, 17, @bitone --diskwritesphysical
exec sp_trace_setevent @tridl, 45, 18, @bitone --cpu time

if @shorttraceexists = 0
        begin
        --select trace columns to show for completed statements on short trace
        exec sp_trace_setevent @trids, 41, 1, @bitone -- textdata
        exec sp_trace_setevent @trids, 41, 3, @bitone -- dbid
        exec sp_trace_setevent @trids, 41, 10, @bitone -- applicationname
        exec sp_trace_setevent @trids, 41, 12, @bitone --spid
        exec sp_trace_setevent @trids, 41, 13, @bitone -- duration in microseconds
        exec sp_trace_setevent @trids, 41, 15, @bitone -- endtime
        exec sp_trace_setevent @trids, 41, 16, @bitone --diskreadslogical
        exec sp_trace_setevent @trids, 41, 17, @bitone --diskwritesphysical
        exec sp_trace_setevent @trids, 41, 18, @bitone --cpu time
        --select trace columns to show for completed sp statements on short trace
        exec sp_trace_setevent @trids, 45, 1, @bitone -- textdata
        exec sp_trace_setevent @trids, 45, 3, @bitone -- dbid
        exec sp_trace_setevent @trids, 45, 10, @bitone -- applicationname
        exec sp_trace_setevent @trids, 45, 12, @bitone --spid
        exec sp_trace_setevent @trids, 45, 13, @bitone -- duration in microseconds
        exec sp_trace_setevent @trids, 45, 15, @bitone -- endtime
        exec sp_trace_setevent @trids, 45, 16, @bitone --diskreadslogical
        exec sp_trace_setevent @trids, 45, 17, @bitone --diskwritesphysical
        exec sp_trace_setevent @trids, 45, 18, @bitone --cpu time
        end

--set filters
exec sp_trace_setfilter @tridl, 13, 0, 4, @currentduration  -- set duration of long trace >=
exec sp_trace_setfilter @tridl, 12, 0, 1, @spid  -- dont trace this spid's actions
if @shorttraceexists = 0
        begin
        exec sp_trace_setfilter @trids, 13, 0, 3, @mindurationforlongtrace -- set duration of short trace < long trace
        exec sp_trace_setfilter @trids, 13, 0, 4, @mindurationforshorttrace -- set duration of short trace >=1
        exec sp_trace_setfilter @trids, 12, 0, 1, @spid  -- dont trace this spid's actions
        end

longtraceexists:
if  (select count(*) from tempdb..sysobjects where name like '%heaviesttracesave%') <> 0
        begin
        select @laststmtendtime = laststmtendtime,
                @lastsampletime = lastsampletime,
                @laststmtendtimes = laststmtendtimes,
                @lastsampletimes = lastsampletimes
                from ##heaviesttracesave
        end
else
        begin
        create table ##heaviesttracesave(laststmtendtime datetime, lastsampletime datetime, laststmtendtimes datetime, lastsampletimes datetime)
        insert into ##heaviesttracesave values (getdate(), getdate(), getdate(), getdate())
        end

if @bypasscollection = 1
        goto bypasscollection

-- process deep infrequent "short" trace
exec sp_trace_setstatus @trids, 1  -- start the short trace
waitfor delay '00:00:01' -- give the short trace exactly a second to run
exec sp_trace_setstatus @trids, 0 -- stop the short trace

-- trace file processing and consolidation starts here

if  (select count(*) from tempdb..sysobjects where name like '%heaviesttraceusage%') = 0
        create table ##heaviesttraceusage(
                [tsqlhashcode] [bigint] not null,
                [databaseid] [int] not null,
                [noofruns] [int] not null,
                [estimated] [bit] not null,
                [totcpu] [bigint] not null,
                [totio] [bigint] not null,
                [totduration] [bigint] not null,
                [highduration] [bigint] not null,
                [applicationname] [nvarchar] (256) null,
                [tsqltext] [nvarchar](4000) not null,
        constraint [pk_traceusage] primary key clustered
        (       [tsqlhashcode] asc, [databaseid] asc))
--      with (data_compression = page) sql 2008 only

select @multiplier = datediff(second, @lastsampletimes, getdate())
if @multiplier < 1
        select @multiplier = 1

select @tracerowsfound = 0

select top 1 @tracetablelong=convert(nvarchar(512),value)
        from sys.fn_trace_getinfo(0)
        where property = 2 and traceid=@tridl
select top 1 @tracetableshort=convert(nvarchar(512),value)
        from sys.fn_trace_getinfo(0)
        where property = 2 and traceid=@trids

-- select @tracetablelong = @tracepathl + '.trc',
--        @tracetableshort = @tracepaths + '.trc'

declare traceoutput cursor fast_forward for
        select 0, textdata, databaseid, applicationname, duration, endtime, reads, writes, cpu
                from fn_trace_gettable(@tracetablelong, default)
                where duration > @mindurationforlongtrace and
                        endtime > @laststmtendtime and
                        textdata is not null
        union all
        select 1, textdata, databaseid, applicationname, duration, endtime, reads, writes, cpu
                from fn_trace_gettable(@tracetableshort, default)
                where duration > 0 and
                        endtime > @laststmtendtimes and
                        textdata is not null

open traceoutput

fetch next from traceoutput into @estimated, @textdata, @databaseid, @applicationname, @duration, @endtime, @reads, @writes, @cpu

while @@fetch_status = 0
        begin
        -- i have used a simple checksum hash for the tsqlhashcode col after stripping off the parameters
        -- but the actual tsql is saved in the tracetsql table with parameters for easy evaluation
        select @textdata = ltrim(rtrim(@textdata)), @position = 1, @asciiposition = 1, @tsqlhashcode = 0, @multilineskip = 0, @singlelineskip = 0
        while @position <= len(@textdata)
                begin
                select @twocharacter = substring(@textdata, @position, 2)
                if @twocharacter = '/*' collate sql_latin1_general_cp1_ci_as and @singlelineskip = 0
                        begin
                        set @multilineskip = 1
                        set @position = @position + 2
                        continue
                        end
                if @twocharacter = '*/' collate sql_latin1_general_cp1_ci_as and @singlelineskip = 0
                        begin
                        set @multilineskip = 0
                        set @position = @position + 2
                        continue
                        end
                if @twocharacter = '--' collate sql_latin1_general_cp1_ci_as and @multilineskip = 0
                        begin
                        set @singlelineskip = 1
                        set @position = @position + 2
                        continue
                        end
                select @onecharacterascii = ascii(substring(upper(@twocharacter), 1, 1))
                if (@onecharacterascii between 10 and 13) and @multilineskip = 0
                        begin
                        set @singlelineskip = 0
                        set @position = @position + 1
                        continue
                        end
                if @multilineskip = 0 and @singlelineskip = 0 and @onecharacterascii <> 32
                        select @tsqlhashcode = @tsqlhashcode + (@onecharacterascii * @asciiposition)
                set @position = @position + 1
                if @onecharacterascii <> 32
                        set @asciiposition = @asciiposition + 1
                end
        if @estimated = 0
                begin
                select @multiplierthisrow = 1
                select @tracerowsfound = @tracerowsfound + 1
                if @endtime > @laststmtendtime
                        select @laststmtendtime = @endtime
                end
        else
                select @multiplierthisrow = @multiplier
        if @endtime > @laststmtendtimes
                select @laststmtendtimes = @endtime
        select @previoushighduration = highduration
                from ##heaviesttraceusage
                where tsqlhashcode = @tsqlhashcode and
                        databaseid = @databaseid
        if @@rowcount = 0
                begin
                insert into ##heaviesttraceusage values (@tsqlhashcode, @databaseid, @multiplierthisrow, @estimated, (@cpu * @multiplierthisrow), ((@reads + @writes) * @multiplierthisrow), (@duration * @multiplierthisrow), @duration, @applicationname, @textdata)
                select @uniquetsql = @uniquetsql + 1
                end
        else
                if @duration > @previoushighduration
                        begin
                        update ##heaviesttraceusage
                                set noofruns = ##heaviesttraceusage.noofruns + @multiplierthisrow,
                                        totcpu = totcpu + (@cpu * @multiplierthisrow),
                                        totio = totio + ((@reads + @writes) * @multiplierthisrow),
                                        totduration = totduration + (@duration * @multiplierthisrow),
                                        highduration = @duration,
                                        tsqltext = @textdata
                                where tsqlhashcode = @tsqlhashcode and
                                        databaseid = @databaseid
                        end
                else
                        update ##heaviesttraceusage
                                set noofruns = ##heaviesttraceusage.noofruns + @multiplierthisrow,
                                        totcpu = totcpu + (@cpu * @multiplierthisrow),
                                        totio = totio + ((@reads + @writes) * @multiplierthisrow),
                                        totduration = totduration + (@duration * @multiplierthisrow)
                                where tsqlhashcode = @tsqlhashcode  and
                                        databaseid = @databaseid

        fetch next from traceoutput into @estimated, @textdata, @databaseid, @applicationname, @duration, @endtime, @reads, @writes, @cpu
        end

close traceoutput
deallocate traceoutput

update ##heaviesttracesave
        set laststmtendtime = @laststmtendtime,
                lastsampletime = getdate(),
                laststmtendtimes = @laststmtendtimes,
                lastsampletimes = getdate()

if @dbg=1 exec sp__printf 'get current duration from long trace'
select @currentduration = convert(int,value)
        -- select * from fn_trace_getfilterinfo(0)
        from fn_trace_getfilterinfo(@tridl)
        where columnid = 13 ;  -- get current duration

select @secsincelastcollection = datediff (ss, @lastsampletime, getdate())
if (@tracerowsfound / (@secsincelastcollection / 60.00) > @nooftsqlstmtsperminhighwater) or
        ((@tracerowsfound / (@secsincelastcollection / 60.00) < @nooftsqlstmtsperminlowwater) and
        (@currentduration > @mindurationforlongtrace)) --too many or too few rows collected, adjust filter
        begin
        if @dbg=1 exec sp__printf 'stop and close long trace %d',@tridl
        exec sp_trace_setstatus @tridl, 0 -- stop the trace
        exec sp_trace_setstatus @tridl, 2 -- close the trace
        select @oldduration = @currentduration
        if @tracerowsfound / (@secsincelastcollection / 60.00) > @nooftsqlstmtsperminhighwater
                begin
                select @gatherwaittimeinsecs = @gatherwaittimeinsecs / 5
                select @currentduration = (((@tracerowsfound / (@secsincelastcollection / 60.00)) / @nooftsqlstmtsperminhighwater) * 0.25 * @currentduration) + @currentduration
                end
        else
                begin
                select @gatherwaittimeinsecs = @gatherwaittimeinsecs / 4 -- should be 3
                select @currentduration = @currentduration / 1.5
                if @currentduration < @mindurationforlongtrace
                        select @currentduration = @mindurationforlongtrace
                end
        goto createlongtrace
        end

bypasscollection:
if @dbg=1 exec sp__printf 'restart long trace %d',@tridl
exec sp_trace_setstatus @tridl, 1 -- re-start the trace as it may have been stopped manually or automatically

select @execstring = 'waitfor delay ''00:00:' + convert(varchar(2), @gatherwaittimeinsecs) + ''''
exec (@execstring)
---derive statistical deviation
if  (select count(*) from tempdb..sysobjects where name like '%heaviesttraceusage%') <> 0
        select @statisticalaverageduration = avg(totduration/noofruns)
                from ##heaviesttraceusage
                where tsqlhashcode in (select top (@statisticalsamplesize) with ties tsqlhashcode
                                                                                        from ##heaviesttraceusage
                                                                                        order by totduration/noofruns desc)
if @statisticallastaverageduration is not null
        select @statisticaldeviation = abs(1 - ((@statisticalaverageduration * 1.0000) / (@statisticallastaverageduration * 1.0000)))
        select @statisticallastaverageduration = @statisticalaverageduration

if (datediff(minute,@starttracetime, getdate()) >= @mintracetimeinminutes) and
        ((datediff(minute,@starttracetime, getdate()) >= @maxtracetimeinminutes) or
        ((@uniquetsql > @statisticalminimumpopulation) and (@statisticaldeviation < 0.03))) -- less than 3% deviation
        goto exitroutine
goto gather

exitroutine:
if @dbg=1 exec sp__printf 'stop and close traces %d and %d',@tridl,@trids

exec sp_trace_setstatus @tridl, 0 -- stop the long trace
exec sp_trace_setstatus @tridl, 2 -- close the long trace
exec sp_trace_setstatus @trids, 0 -- stop the short trace
exec sp_trace_setstatus @trids, 2 -- close the short trace

if  (select count(*) from tempdb..sysobjects where name like '%heaviesttracesave%') <> 0
        drop table ##heaviesttracesave

-- give statistical confidence indicator as a percentage
select 100-(@statisticaldeviation*100) as [confidence %]

-- show heaviest tsql (all runs)
select noofruns as [number of executions],
                totcpu,
                totio,
                totduration as [total duration (microseconds)],
                highduration as [longest duration (microseconds)],
                totduration/noofruns as [ave duration (microseconds)],
                db_name(databaseid) as [database],
                tsqltext,
                applicationname
        from ##heaviesttraceusage
        order by 4 desc

drop table ##heaviesttraceusage
goto ret
-- =================================================================== errors ==
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    Two level - Self adjusting trace to capture worst performing
    TSQL statements using a sampling technique
    Output is stored in a table which is finally output once statistical
    confidence is high enough or sample time expires

Notes
    - originally from http://sqlserverperformance.idera.com/tsql-optimization/finding-heaviest-tsql-optimize-sql-server/

Parameters
    @MaxTraceTimeInMinutes  routine may exit sooner if enough samples
                            have been gathered (normally 20 minutes)
    @MinTraceTimeInMinutes  (optional) minimum time to run even if statistics
                            have "settled" (normally 75%:15 minutes)

Examples
    exec sp__profile 20

'
select @ret=-1
-- ===================================================================== exit ==

ret:
return @ret
end -- sp__profile