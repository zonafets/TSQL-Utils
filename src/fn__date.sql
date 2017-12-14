/*  leave this
    l:see LICENSE file
    g:utility
    k:date,without,time,getdate,convert,number
    s:fn__time
    v:131117\s.zaglio: out a int instead of a date to align to fn__time
    v:130828\s.zaglio: return a date without time (more a reminder that to use everyday)
    t:select dbo.fn__date(getdate())
    t:
        select
            -- round a date to the nearest quarter
            cast(floor(cast(getdate() as float(53))*24*4)/(24*4) as datetime),
            -- faster but untill y5500; there was rounding issues at 30 and 00
            dateadd(minute, datediff(minute,0,getdate()) / 15 * 15, 0),
            -- last 15 minute increment, not the nearest
            cast(round(floor(cast(getdate() as float(53))*24*4)/(24*4),5) as smalldatetime)
*/
CREATE function fn__date(@dt datetime)
returns int
as
begin
return cast(convert(varchar(8),dateadd(dd, datediff(dd, 0, getdate())+0, 0),112) as int)
end -- fn__date