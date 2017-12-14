/*  leave this
    l:see LICENSE file
    g:utility
    v:131020\s.zaglio: get server ip
    t:
        create proc tst_server_ip
        as declare @ip sysname exec sp__server_ip @ip out print '-'+@ip
        go
        exec tst_server_ip
        drop proc tst_server_ip
*/
CREATE proc sp__server_ip(@ip sysname=null out)
as
begin
declare @cmd sysname
declare @out table(line sysname null)
select @cmd='@for /f "tokens=5 delims= " %d '
           +'in (''ping %srv% -4 -n 1 ^| find /i "ping %srv%"'') '
           +'do @echo %d'
select @cmd=replace(@cmd,'%srv%',cast(serverproperty('machinename') as sysname))
insert @out exec xp_cmdshell @cmd
select top 1 @ip=substring(line,2,len(line)-2) from @out
if @@nestlevel=1 and dbo.fn__isconsole()=1 print @ip
end -- sp__server_ip