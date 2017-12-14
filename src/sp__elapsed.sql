/*  leave this
    l:see LICENSE file
    g:utility
    v:130725,130724,130605\s.zaglio: +days;refactoring;removed printf deprecated parameters
    v:121012.1155\s.zaglio: excluded sp__elapsed time and changed behaviour for help
    v:111115\s.zaglio: replace %d/s with (null) and added help
    v:110526\s.zaglio: added variant ( at end of @c
    v:090916\s.zaglio: added minutes/secs/ms output format
    v:090629\S.Zaglio: added %t
    v:090626\S.Zaglio: added @v1,@v2,@v3,@v4
    v:090616\S.Zaglio: used sp__printf with force
    v:090122\S.Zaglio: print elapsed ms from @d to now
    c:in the future will calibrate it self to subtract inprocess time
    t:exec sp__elapsed '2013-07-24T11:34:40.000','test('
*/
CREATE proc [dbo].[sp__elapsed](
    @d datetime=null out,
    @c sysname=null,@ms int=null out,
    @v1 sql_variant=null,@v2 sql_variant=null,
    @v3 sql_variant=null,@v4 sql_variant=null
    )
as
begin
declare @proc sysname -- not set here to save time
declare @now datetime select @now=getdate()
declare @dd int, @hh int, @mm int,@ss int
declare @open nvarchar(1),@close nvarchar(1)
if @d=0
or (@@nestlevel=1 and @d is null) goto help

if not @c is null
    begin
    select @c=replace(@c,'%t',convert(sysname,getdate(),126))
    -- if not @v1 is null or not @v2 is null or not @v3 is null or not @v4 is null
    select @c=dbo.fn__printf(@c,@v1,@v2,@v3,@v4,null,null,null,null,null,null)
    end

if not @c is null
    if right(@c,1)='(' select @open='',@close=')'
    else select @open=':',@close=''

if @d is null
    begin
    select @d=@now
    if not @c is null
        exec sp__printf '%s%s%s%s',
                        @c,@open,@d,@close
    end
else begin
    select @ms=datediff(ms,@d,@now)
    select @d=@now
    if not @c is null
        begin
        if @ms>86399999 -- days
            begin
            select @dd=@ms/86400000,@ms=@ms%86400000
            select @hh=@ms/3600000,@ms=@ms%3600000
            select @mm=@ms/60000,@ms=@ms%60000
            select @ss=@ms/1000,@ms=@ms%1000
            exec sp__printf '%s%s%dd %dh %dm %ds %sms%s',
                            @c,@open,@dd,@hh,@mm,@ss,@ms,@close
            /* if @hh=0 -- but not really necessary to loose perf.
                exec sp__printf '%s%s24h %dm %ds %sms%s',
                                @c,@open,@mm,@ss,@ms,@close */
            goto ret
            end
        if @ms>59999 -- mins
            begin
            select @mm=@ms/60000,@ms=@ms%60000
            select @ss=@ms/1000,@ms=@ms%1000
            exec sp__printf '%s%s%dm %ds %sms%s',
                            @c,@open,@mm,@ss,@ms,@close
            end
        else if @ms>999 -- secs
            begin
            select @ss=@ms/1000,@ms=@ms%1000
            exec sp__printf '%s%s%ds %sms%s',
                            @c,@open,@ss,@ms,@close
            end
        else
            exec sp__printf '%s%s%dms%s',
                            @c,@open,@ms,@close
        end
    end
ret:
select @d=getdate() -- to exclude sp__elapsed time
return 0

help:
select @proc=object_name(@@procid)
exec sp__usage @proc,'
Scope
    help trace times of application

Notes
    if run from a sp, work well for back compatibility

Parameters
    @d      is the last datetime elapsed
    @c      is an optional comment (if null do not print nothing)
    @ms     are the ms elapsed from @d
    @v1...  replace %s,%d in @c (use sp__printf)

Examples
    declare @d datetime,@ms int select @d=getdate()
    exec sp__elapsed @d out,@ms=@ms out
    print @ms waitfor delay "00:00:01"
    exec sp__elapsed @d out,"after example"

'

select @d=getdate() -- for compatibility of execution
return -1
end -- sp__elapsed