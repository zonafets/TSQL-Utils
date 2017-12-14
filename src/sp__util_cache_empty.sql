/*  leave this
    l:see LICENSE file
    g:utility
    v:091209\s.zaglio
*/
create proc sp__util_cache_empty
as
begin
checkpoint;
dbcc dropcleanbuffers;
end -- proc