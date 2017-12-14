/*  leave this
    l:see LICENSE file
    g:utility
    o:130209.1000\s.zaglio: fn__isjob
    v:131215\s.zaglio: maybe more compatible with future versions of mssql
    v:130209.1000\s.zaglio: return job info about @@spid
    t:sp__job_test
*/
CREATE function fn__job(@spid int)
returns table
as
return
select top 1 job_id,name,loginame
-- select top 1 *
from master..sysprocesses ss
join msdb..sysjobs
on  rtrim(ltrim(dbo.fn__str_between(ss.program_name,'job ',' :',default)))
    =
    dbo.fn__hex(convert(varbinary,job_id))
where spid=@spid
and left([program_name],8)='SQLAgent'
and hostname=left(@@servername,len(hostname))    -- istance is not passed
/*    this is not really necessary
and ltrim(rtrim(loginame)) in (
    dbo.fn__job_agent(),        /*    this return different values:
                                    LocalSystem instead of NT AUTH..\SYSTEM
                                    names in system language instead of local */
    'NT AUTHORITY\SYSTEM','SQLServerAgentSVC',    -- mssql2k and 2k5
    'SERVIZIO DI RETE',                            -- italian lang
    'servicesql'                                -- on mssql2k12
    )
*/
-- fn__job