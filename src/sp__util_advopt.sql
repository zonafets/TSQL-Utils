/*  leave this
    g:utility
    v:100405\s.zaglio: show lòcal ad options
    v:100228\s.zaglio: activate advanced option on remote linked server
    t:sp__util_advopt '.'
*/
CREATE proc [dbo].[sp__util_advopt] @svr sysname=null
as
begin
set nocount on
if @svr is null goto help

declare @sql nvarchar(4000)

select @sql='
EXECUTE %svr%..sp_configure "show advanced options", 1 RECONFIGURE WITH OVERRIDE
reconfigure
EXECUTE %svr%..sp_configure "Ad Hoc Distributed Queries",1 RECONFIGURE WITH OVERRIDE
EXECUTE %svr%..sp_configure "xp_cmdshell", "1" RECONFIGURE WITH OVERRIDE
EXECUTE %svr%..sp_configure "Ole Automation Procedures", "1" RECONFIGURE WITH OVERRIDE
EXECUTE %svr%..sp_configure "SMO and DMO XPs", "1" RECONFIGURE WITH OVERRIDE
EXECUTE %svr%..sp_configure "clr enabled", "1" RECONFIGURE WITH OVERRIDE
-- MSSQL2008
-- EXECUTE sp_configure "Ad Hoc Distributed Queries",1 RECONFIGURE WITH OVERRIDE
EXECUTE %svr%..sp_configure
EXECUTE %svr%..sp_configure "show advanced options", 0 RECONFIGURE WITH OVERRIDE
reconfigure
'
select @sql=replace(@sql,'"','''')
if @svr='.' select @sql=replace(@sql,'%svr%..','')
else select @sql=replace(@sql,'%svr%','['+@svr+']')
exec sp__printf @sql
exec(@sql)
goto ret

help:
exec sp__printf 'Enable advanced options (openroset,xp_cmdshell, etc) on remote server'
exec sp__printf 'Use "." on local server'
EXECUTE sp_configure "show advanced options", 1 RECONFIGURE WITH OVERRIDE
reconfigure
EXECUTE sp_configure
EXECUTE sp_configure "show advanced options", 0 RECONFIGURE WITH OVERRIDE
reconfigure

ret:
end -- sp__util_advopt