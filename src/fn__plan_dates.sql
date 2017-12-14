/*  leave this
    l:see LICENSE file
    g:utility,plan
    k:plan,calendar,planning
    r:121118\s.zaglio: convert plan calendar structure into dates
    t:sp__plan_calendar_test
*/
CREATE function fn__plan_dates(
    @year int,
    @days nvarchar(24)    -- 12 int:bit0=01/01
    )
returns @t table (dt datetime)
as
begin
/*
    declare @t table (dt datetime)
    declare @year int,@days varchar(48)
    select @year=2012,@days=cast(1 as varchar(48))
    select cast(@days as varbinary(48))
*/
declare @pmm int,@chunk binary(4),@dt datetime,@dayp2 bigint,@day int,@month int
select
    @dt=0,
    @dt=dateadd(yy,@year-year(0),@dt),
    @month=0,
    @pmm=1

-- select * from dbo.fn__plan_dates(2012,cast(1 as varchar(48)))

while @pmm<=len(@days)
    begin
    select @chunk=cast(substring(@days,@pmm,2) as binary(4))
    select @day=0,@dayp2=1
    while @day<31
        begin
        /*
        exec sp__printf
                'chunk:%d, pmm:%d, day:%d, dp2:%d',
                @chunk,@pmm,@day,@dayp2
        */
        if @chunk&@dayp2=@dayp2 insert @t select dateadd(mm,@month,@dt)+@day
        select @day=@day+1,@dayp2=@dayp2*2
        end
    select @pmm=@pmm+2,@month=@month+1
    end

-- select * from @t

return
end -- fn__plan_dates