/*  leave this
    l:see LICENSE file
    g:utility
    k:date,first,day,sunday,set datefirst
    c:http://stackoverflow.com/questions/7168874/get-first-day-of-week-in-sql-server
    c:more a reminder that to use everyday
    v:131117\s.zaglio: get 1st sunday of week
    t:select dbo.fn__dt_sunday_of_week(getdate())
*/
create function dbo.fn__dt_sunday_of_week
(
    @d smalldatetime
)
returns smalldatetime
as
begin
    return (select dateadd(week, datediff(week, '19050101', @d), '19050101'));
end -- fn__dt_sunday_of_week