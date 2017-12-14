/*  leave this
    l:see LICENSE file
    g:utility
    v:080402\S.Zaglio: read/write/delete a registry (of MSSQLServer\MyGlobalVars branch) with value
    t:print dbo.fn__global_var('test','test value') print dbo.fn__global_var('test','test 1') print dbo.fn__global_var('test',null)
    t:
        DECLARE @AuditLevel int

        EXEC master..xp_regread
          @rootkey='HKEY_LOCAL_MACHINE',
          @key='SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
          @value_name='AuditLevel',
          @value=@AuditLevel OUTPUT

        SELECT @AuditLevel
*/
CREATE  function [dbo].[fn__global_var](@variable sysname,@value nvarchar(4000))
returns nvarchar(4000)
as
begin
declare @var sysname,@key sysname
select  @key='SOFTWARE\Microsoft\MSSQLServer\MSSQLServer',
        @variable='fgv_'+@variable
if @value is null begin
    EXECUTE master..xp_regdeletevalue 'HKEY_LOCAL_MACHINE',@var,@variable
    return null
    end
declare @old_value nvarchar(4000)
EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE',@key,@variable,@old_value out
if @old_value is null begin
    EXECUTE master..xp_regwrite 'HKEY_LOCAL_MACHINE',@key,@variable,'REG_SZ',@value
    EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE',@key,@variable,@value out
    return @value
    end
return @old_value
end