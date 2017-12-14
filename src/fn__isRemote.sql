/*  leave this
    l:see LICENSE file
    g:utility
    v:120103\s.zaglio:seems to works
    r:101211\s.zaglio:return 1 if the sp is called from a remote server
    c:replace @@remserver
*/
CREATE function fn__isRemote(@spid int)
returns bit
as
begin
if exists(
    select null
    from master..sysprocesses
    where spid=@spid
    and app_name()='Microsoft SQL Server'
    -- and left([program_name],8)='SQLAgent'
    -- and hostname=@@servername
    and nt_username=''
    and nt_domain=''
    )
    return 1
return 0
end -- fn__isRemote