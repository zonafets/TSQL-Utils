/*  leave this
    l:see LICENSE file
    g:utility
    v:080402\S.Zaglio: read/write from a registry (of MSSQLServer\MyGlobalVars branch) the value
    t:print dbo.fn__global_set('test','test value') print dbo.fn__global_get('test')
*/
CREATE  function [dbo].[fn__global_set](@variable sysname,@value nvarchar(4000))
returns nvarchar(4000)
as
begin
declare @var sysname,@key sysname
select  @key='SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
        @var='fgv_'+@variable
EXECUTE master..xp_regwrite 'HKEY_LOCAL_MACHINE',@key,@var,'REG_SZ',@value
select @value=null
EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE',@key,@var,@value out
return @value
end