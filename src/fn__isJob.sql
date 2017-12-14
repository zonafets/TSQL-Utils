/*  leave this
    l:see LICENSE file
    g:utility
    v:110321\s.zaglio:added italian "SERVIZIO DI RETE"
    v:110213\s.zaglio:added SQLServerAgentSVC and exclusion of instance
    v:101211\s.zaglio:return 1 if the @spid is executed from a job
*/
CREATE function fn__isJob(@spid int)
returns bit
as
begin
if exists(
    select spid,program_name,hostname,nt_username
    from master..sysprocesses
    where spid=@spid
    and left([program_name],8)='SQLAgent'
    and hostname=left(@@servername,len(hostname)) -- istance is not passed
    and ltrim(rtrim(nt_username)) in ('SYSTEM','SQLServerAgentSVC','SERVIZIO DI RETE')
    )
    return 1
return 0
end -- fn__isJob