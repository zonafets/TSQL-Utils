/*  leave this
    l:see LICENSE file
    g:utility
    k:is,console,ssms,app_name,test
    v:131208\s.zaglio:added check of SSDT
    v:130106.1000\s.zaglio:return 1 if app_name is a console like SSMS
    t:select dbo.fn__isConsole()
*/
CREATE function fn__isConsole()
returns bit
as
begin
-- works only locally because app_name() of a remote call is
-- mssql or ms.client or ...
if left(app_name(),39)='Microsoft SQL Server Management Studio'
or left(app_name(),31)='Microsoft SQL Server Data Tools'
    return 1
return 0
end -- fn__isConsole