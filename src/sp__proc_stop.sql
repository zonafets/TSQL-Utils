/*  leave this
    v:091026\s.zaglio: stop or show how to breack run of code without close connection
    c:this is only to not loose too much time to read,understand,verify the manual
    g:utility
*/
CREATE proc sp__proc_stop @proc sysname=null,@msg sysname=null,@severity int=17
as
begin
if @proc is null or @msg is null goto help
raiserror('%s:%s',@severity,1,@proc,@msg)
help:
exec sp__usage 'sp__proc_stop'
end