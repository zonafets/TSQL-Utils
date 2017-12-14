/*  leave this
    l:see LICENSE file
    g:utility,trace
    r:110321\s.zaglio:sync scripts with gates and servers
*/
CREATE proc sp__trace_queue
as
begin
-- exec sp__log 'trace-sync'
print 'some tests but with errors on contract. See code'
goto ret

declare @h uniqueidentifier,@b varbinary(max),@t sysname

-- select db_name(database_id) db,object_name(queue_id) q,* from sys.dm_broker_queue_monitors

-- drop queue sync_queue
if object_id('sync_queue') is null
    create queue sync_queue with status=on, activation (procedure_name=sp__sync_queue, max_queue_readers = 1, EXECUTE AS 'tempsa')

-- drop service sync_service
create service sync_service
on queue sync_queue

-- drop route sync_route
create route sync_route
with service_name='sync_service',address='local'

-- drop message type sync_sql
create message type sync_sql

-- drop contract sync_contract
create contract sync_contract(sync_sql sent by any)

alter database utility
set enable_broker
with rollback immediate


-- declare @h uniqueidentifier
begin dialog conversation @h
    from service sync_service
    to service 'sync_service'
    on contract sync_contract
    with encryption=off

print @h

-- to prevent error 8429
-- select * from sys.conversation_endpoints
/*
alter queue trace_queue
with status = on , retention = off ,
activation ( status = off )

alter queue trace_queue
with status = on , retention = off ,
activation ( status = on )
*/
-- declare @h uniqueidentifier
select @h='C9E9D502-C553-E011-B483-D48564540B5A'
;send on conversation @h
message type sync_sql('test queue')

-- select * from sys.transmission_queue
-- select db_name(database_id) db,object_name(queue_id) q,* from sys.dm_broker_queue_monitors
-- select * from sys.dm_broker_activated_tasks
select * from sync_queue

select @h='C9E9D502-C553-E011-B483-D48564540B5A'
;receive top(1)
    @h=conversation_handle,
    @t=message_type_name,
    @b=message_body
from sync_queue

print @h
print @t
print convert(nvarchar(max),@b)
print convert(nvarchar(max),convert(xml,@b))

-- declare @h uniqueidentifier select @h='CFA7D379-A653-E011-B483-D48564540B5A'
end conversation @h  -- also prevent error 8429

ret:
end -- sp__trace_sync