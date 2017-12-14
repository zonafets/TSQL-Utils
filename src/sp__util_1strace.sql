/*  leave this
    l:see LICENSE file
    g:utility
    v:101130\s.zaglio: show current trace info
    t:select * from ::fn_trace_getinfo(default)
*/
create proc sp__util_1strace
as
begin

-- SELECT 0, TextData, DatabaseID, ApplicationName, Duration, EndTime, Reads, Writes, CPU
select StartTime,EndTime,TextData,Reads, Writes, CPU,*
from fn_trace_gettable((select convert(nvarchar(512),[value]) from ::fn_trace_getinfo(default) where traceid=1 and [property]=2), default)
where 1=1
and StartTime>getdate()-0.1
and TextData IS NOT NULL

end -- sp__util_1strace