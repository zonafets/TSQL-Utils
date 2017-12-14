/*  leave this
    l:see LICENSE file
    g:utility,sync
    v:110321\s.zaglio: receive/send messages
*/
CREATE proc sp__trace_event
as
begin
set nocount on
declare @proc sysname,@ret int,@err int,@dbg int
select @proc=object_name(@@procid),@ret=0,@err=0,@dbg=isnull(@dbg,0)
print 'in sp__trace_event'

while (1=1)
    begin
    declare @body nvarchar(max),@type sysname
    waitfor (
        receive top(1)
            @type=message_type_name,
            @body=message_body
            from trace_queue
        ), timeout 500
    -- if there is no message exit
    if @@rowcount=0 break;
    if @type='http://schemas.microsoft.com/SQL/Notifications/PostEventNotification'
        begin
        declare @data xml
        select @data=cast(@body as xml)
        declare @et sysname,@obj sysname,@sql nvarchar(max)
        select
            @et=EVENTDATA().value('(/EVENT_INSTANCE/EventType)[1]','nvarchar(256)'),
            @obj=EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]','nvarchar(256)'),
            @sql=EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand)[1]','nvarchar(max)')
        exec sp__trace_store @et,@obj,@sql
        end
    end -- while

end -- sp__trace_event