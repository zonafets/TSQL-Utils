/*  leave this
    l:see LICENSE file
    g:utility
    k:date,first,day,week,set DATEFIRST
    c:http://stackoverflow.com/questions/7168874/get-first-day-of-week-in-sql-server
    c:more a reminder that to use everyday
    v:131117\s.zaglio: get 1st day of week
    t:select dbo.fn__dt_first_weekday(getdate())
*/
CREATE function fn__dt_first_weekday( -- always the datefirst weekday
    @d smalldatetime
)
returns smalldatetime
as
begin
    return (select dateadd(day, 1-datepart(weekday, @d), @d));
end -- fn__dt_first_weekday