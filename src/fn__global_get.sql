/*  leave this
    l:see LICENSE file
    g:utility
    v:080402\S.Zaglio: read from a registry (of MSSQLServer\MyGlobalVars branch) the value
*/
CREATE  function fn__global_get(@variable sysname)
returns nvarchar(4000)
as
begin
declare @value nvarchar(4000)
EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\MSSQLServer\MSSQLServer\MyGlobalVars',@variable,@value out
return @value
end