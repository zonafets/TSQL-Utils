/*  leave this
    l:see LICENSE file
    g:utility,plan
    k:plan,calendar,planning
    r:121118\s.zaglio: store a date into the plan calendar strtucture
    t:sp__plan_calendar_test
*/
CREATE function fn__plan_calendar(
    @dt datetime,
    @days nvarchar(24)    -- 12 int:bit0=01/01
    )
returns nvarchar(24)
as
begin
/*
declare
    @dt datetime,
    @days varchar(48)    -- 12 int:bit0=01/01
select
    @dt='2012-01-02',       -- ydm
    @days=''
*/
declare
    @l int,
    @pmm int,               -- byte position of month
    @dd bigint,
    @chunk binary(4)     -- days buffer

select
    @l=datalength(@days),
    @pmm=(month(@dt)-1)*2+1,
    @dd=power(2,day(@dt)-1)

-- select @dt dt,@days days,@l l,@pmm pmm,@dd dd

if @l<@pmm+2
    select @days=@days+replicate(char(0),@pmm+2-1-@l)

select
    @chunk=cast(substring(@days,@pmm,2) as binary(4))|@dd

-- select datalength(@days) len_days,@chunk chunk

/*
select @days=
    convert(varbinary(48),
        stuff(
            convert(varchar(48),@days),
            @pmm,
            4,
            convert(varchar(4),@chunk)
            )
        )
*/
select @days=substring(@days,1,@pmm-1)+cast(@chunk as nchar(2))
            +substring(@days,@pmm+2,48)

-- select cast(@days as varbinary(48)) result

return @days
end -- fn__plan_calendar