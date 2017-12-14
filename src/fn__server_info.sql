/*  leave this
    l:see LICENSE file
    g:utility
    d:130517\s.zaglio:sp__clientip
    d:130517\s.zaglio:sp__serverip
    d:130517\s.zaglio:sp__parse_conn
    v:130517\s.zaglio:return info about this server, changed from txt to tbl
    v:081003\s.zaglio:old version
    t:select * from fn__server_info()
*/
CREATE function fn__server_info()
returns table
as
return
select
    coalesce(convert(sysname,serverproperty('machinename')),'') as machine_name,
    coalesce(convert(sysname,serverproperty('servername') ),'') as server_name,
    local_net_address as server_ip,
    coalesce(convert(sysname,serverproperty('instancename')),'') as instance_name,
    local_tcp_port as instance_port,
    coalesce(convert(sysname,serverproperty('edition') ),'') as edition,
    coalesce(convert(sysname,serverproperty('productversion') ),'') as product_version,
    coalesce(convert(sysname,serverproperty('productlevel') ),'') as product_level,
    coalesce(convert(sysname,serverproperty('engineedition')),'') as engine_edition,
    coalesce(convert(sysname,serverproperty('computernamephysicalnetbios')),'') as computer_name_physical_netbios

-- select *
from sys.dm_exec_connections
where session_id=@@spid
-- fn__server_info