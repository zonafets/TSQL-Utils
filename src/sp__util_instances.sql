/*  leave this
    l:see LICENSE file
    g:utility
    v:120112\s.zaglio: list infor about running instances
    c:
        originally from:
        http://social.msdn.microsoft.com/Forums/en/
             sqlsetupandupgrade/thread/fe689d83-0264-45d7-8d73-5b1ac43d09a6
*/
create proc sp__util_instances
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
-- declare -- insert before here --  @end_declare bit
-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
-- ===================================================================== body ==

Declare @CurrID int,@ExistValue int, @MaxID int, @SQL nvarchar(1000)
Declare @TCPPorts Table (PortType nvarchar(180), Port int)
Declare @SQLInstances Table (InstanceID int identity(1, 1) not null primary key,
                                          InstName nvarchar(180),
                                          Folder nvarchar(50),
                                          StaticPort int null,
                                          DynamicPort int null,
                                          Platform int null);
Declare @Plat Table (Id int,Name varchar(180),InternalValue varchar(50), Charactervalue varchar (50))
Declare @Platform varchar(100)
Insert into @Plat exec xp_msver platform
select @Platform = (select 1 from @plat where charactervalue like '%86%')
If @Platform is NULL
Begin
Insert Into @SQLInstances (InstName, Folder)
Exec xp_regenumvalues N'HKEY_LOCAL_MACHINE',
                             N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Update @SQLInstances set Platform=64
End
else
Begin
Insert Into @SQLInstances (InstName, Folder)
Exec xp_regenumvalues N'HKEY_LOCAL_MACHINE',
                             N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Update @SQLInstances Set Platform=32
End
Declare @Keyexist Table (Keyexist int)
Insert into @Keyexist
Exec xp_regread'HKEY_LOCAL_MACHINE',
                              N'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL';
select @ExistValue= Keyexist from @Keyexist
If @ExistValue=1
Insert Into @SQLInstances (InstName, Folder)
Exec xp_regenumvalues N'HKEY_LOCAL_MACHINE',
                              N'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL';
Update @SQLInstances Set Platform =32 where Platform is NULL
Select @MaxID = MAX(InstanceID), @CurrID = 1
From @SQLInstances
While @CurrID <= @MaxID
  Begin
      Delete From @TCPPorts
      Select @SQL = 'Exec xp_instance_regread N''HKEY_LOCAL_MACHINE'',
                              N''SOFTWARE\Microsoft\\Microsoft SQL Server\' + Folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'',
                              N''TCPDynamicPorts'''
      From @SQLInstances
      Where InstanceID = @CurrID
      Insert Into @TCPPorts
      Exec sp_executesql @SQL
      Select @SQL = 'Exec xp_instance_regread N''HKEY_LOCAL_MACHINE'',
                              N''SOFTWARE\Microsoft\\Microsoft SQL Server\' + Folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'',
                              N''TCPPort'''
      From @SQLInstances
      Where InstanceID = @CurrID

      Insert Into @TCPPorts
      Exec sp_executesql @SQL

      Select @SQL = 'Exec xp_instance_regread N''HKEY_LOCAL_MACHINE'',
                              N''SOFTWARE\Wow6432Node\Microsoft\\Microsoft SQL Server\' + Folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'',
                              N''TCPDynamicPorts'''
      From @SQLInstances
      Where InstanceID = @CurrID

      Insert Into @TCPPorts
      Exec sp_executesql @SQL

      Select @SQL = 'Exec xp_instance_regread N''HKEY_LOCAL_MACHINE'',
                              N''SOFTWARE\Wow6432Node\Microsoft\\Microsoft SQL Server\' + Folder + '\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'',
                              N''TCPPort'''
      From @SQLInstances
      Where InstanceID = @CurrID

      Insert Into @TCPPorts
      Exec sp_executesql @SQL

      Update SI
      Set StaticPort = P.Port,
            DynamicPort = DP.Port
      From @SQLInstances SI
      Inner Join @TCPPorts DP On DP.PortType = 'TCPDynamicPorts'
      Inner Join @TCPPorts P On P.PortType = 'TCPPort'
      Where InstanceID = @CurrID;
      Set @CurrID = @CurrID + 1
  End
Select serverproperty('ComputerNamePhysicalNetBIOS') as ServerName, InstName, StaticPort, DynamicPort,Platform
From @SQLInstances

-- goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    list info about running instances

Parameters

Examples
'

-- select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc SP__UTIL_INSTANCES