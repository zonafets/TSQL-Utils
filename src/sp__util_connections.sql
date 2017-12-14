/*  leave this
    l:see LICENSE file
    g:utility
    k:tcp,ip,host,status,client
    v:121025\s.zaglio: list active connections and some useful info
    t:sp__util_connections #
    t:sp__util_connections '%hostname%'
*/
CREATE proc sp__util_connections
    @what sysname = null,
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    -- error vars
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    -- generic common
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @opt1 bit,@opt2 bit,
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @opt1=charindex('|opt|',@opt),
    @end_declare=1

-- ======================================================== second params chk ==
if @what is null goto help

-- ===================================================================== body ==

if @what='#' select @what='%' else select @what='%'+@what+'%'
select @what=replace(@what,'%hostname%',host_name())

select
    c.session_id,
    p.kpid,
    p.lastwaittype,p.waitresource,
    p.status,p.hostname,p.program_name,p.loginame,
    db_name(p.dbid) db,
    c.most_recent_session_id,
    c.connect_time,
    c.num_reads,    c.num_writes,
    c.last_read,    c.last_write,
    c.client_net_address,
    c.client_tcp_port,
    c.local_net_address,
    c.local_tcp_port,
    object_name(s.objectid,s.dbid) obj,
    substring(s.text,p.stmt_start/2,
    (case when p.stmt_end = -1
    then len(convert(nvarchar(max), s.text)) * 2
    else p.stmt_end end - p.stmt_start+3)/2)
    as sql
    --most_recent_sql_handle
    /*
    SELECT substring(text,x.statement_start_offset/2,
    (case when x.statement_end_offset = -1
    then len(convert(nvarchar(max), text)) * 2
    else x.statement_end_offset end - x.statement_start_offset+3)/2)
    -- select * from
    FROM sys.dm_exec_sql_text(x.sql_handle)
    FOR XML PATH(''), TYPE
    ) AS Sql_text
    */

-- select *
from sys.dm_exec_connections c (nolock)
join sys.sysprocesses p (nolock) on c.session_id=p.spid
-- join sys.dm_exec_requests r on c.session_id=r.spid
cross apply sys.dm_exec_sql_text(p.sql_handle) as s
where 1=1
and p.spid!=@@spid
and @what='%'
or (
    p.status like @what
    or p.hostname like @what
    or p.program_name like @what
    or p.loginame like @what
    or db_name(p.dbid) like @what
    )

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
/*
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_me1:    select @e_msg='write here msg'                              goto err
err_me2:    select @e_msg='write this %s',@e_p1=@var                    goto err
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    list active connections and some useful info

Parameters
    @what   a generic filter for each text field
            use # or ''%'' for everithing
    @opt    not used
    @dbg    not used

Examples
    t:sp__util_connections #
    t:sp__util_connections ''%hostname%''
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__util_connections