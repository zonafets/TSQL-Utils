/*  leave this
    l:see LICENSE file
    g:utility
    v:131014.2300\s.zaglio: a small bug under mssql2k12
    v:120726\s.zaglio: add run option and more info
    v:110325\s.zaglio: a modern version
    v:090808\S.Zaglio: added @replace
    v:081229\S.Zaglio: added @err out
    v:081227\S.Zaglio: added nounload,recovery options
    v:081130\S.Zaglio: added @rename to allow fast dublicate of db
    v:081125\S.Zaglio: added mssql2008 compatibility and corrected a bug
    v:081114\S.Zaglio: added comment and mssql2005 compatibility
    v:080509\S.Zaglio: added @simul
    v:080508\S.Zaglio: restore db from file replacing dst file name. Don't manage multi filegroup.
    c:for more advanced versione see http://www.sqlservercentral.com/scripts/Backup+%2F+Restore/32003/
    c:copy this on master db of dest server for first restore
    t:sp__restore 'db','device.bak'
    t:sp__backup '%temp%',@opt='doit',@dbg=1  -- backup this db
    t:sp__restore 'test','C:\DOCUME~1\NETWOR~1\IMPOST~1\Temp\utility_110325_1251.bak'
*/
CREATE proc [dbo].[sp__restore]
    @db         sysname=null,
    @device     nvarchar(1024)=null out,
    @opt        sysname=null,
    @dbg        int=0
as
begin
set nocount on

declare @proc sysname,@ret int
select  @proc=object_name(@@procid),@ret=0,
        @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @db is null goto help
if @db=db_name() goto err_db

-- ============================================================== declaration ==

declare
    @mssqlver smallint,@dbid int,@crlf nvarchar(2),@doit bit,
    @sql nvarchar(4000),@tmp nvarchar(1024)

-- ===================================================================== init ==

select
    @crlf=crlf,
    @doit=case
          when charindex('|doit|',@opt)>0 then 1
          when charindex('|run|',@opt)>0  then 1
          else 0
          end
from fn__sym()

exec sp__get_temp_dir @tmp out
select @device=replace(@device,'%temp%',@tmp)

if @dbg=1 exec sp__printf 'dev=%s, tmp=%s, db=%s, dt=%s',@device, @tmp,@db

/* to enable sp__restore to work on mssql2005/2008
EXECUTE sp_configure 'show advanced options', 1 RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'xp_cmdshell', '1' RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'Ole Automation Procedures', '1' RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'SMO and DMO XPs', '1' RECONFIGURE WITH OVERRIDE
EXECUTE sp_configure 'show advanced options', 0 RECONFIGURE WITH OVERRIDE
*/

if not exists(
    select [name]
    from master..sysdatabases
    where [name]=@db
    )
    begin
    if @doit=1 exec('create database ['+@db+']')
    else goto err_mdb
    end

select @mssqlver=convert(smallint,substring(@@version,22,5))
if not @mssqlver in (2000,2005,2008,2012) goto err_ver

-- drop database @name_db    the dest db must not exist

select @dbid=[dbid]
from master.dbo.sysdatabases
where [name]=@db

if (select count(*)
    from master.dbo.sysaltfiles
    where [dbid]=@dbid
   )>2 goto err_max

-- restore must replace original files with current files

-- destination paths
/*
select @logical_name = null
select @logical_name=rtrim(filename)
from master.dbo.sysaltfiles
where [dbid]=@dbid and fileid=1

select @file_path_data=reverse(@logical_name)
select @i=charindex('\',@file_path_data)
select @file_path_data=substring(@logical_name,1,len(@logical_name)-@i+1)
select @logical_name=rtrim(filename)
from master.dbo.sysaltfiles
where dbid=@dbid and fileid=2

select @file_log=reverse(@logical_name)
select @i=charindex('\',@file_log)
select @file_log=substring(@logical_name,1,len(@logical_name)-@i+1)
*/

create table #Media (
    LogicalName nvarchar(128) NULL,
    PhysicalName nvarchar(260) NULL,
    [Type] nchar(1) NULL,
    FileGroupName nvarchar(128) NULL,
    [Size] numeric(20,0) NULL,
    [MaxSize] numeric(20,0) NULL
    )
if @mssqlver>=2005
    alter table #Media add
    FileID bigint NULL,
    CreateLSN numeric(25,0) NULL,
    DropLSN numeric(25,0) NULL,
    UniqueID uniqueidentifier NULL,
    ReadOnlyLSN numeric(25,0) NULL,
    ReadWriteLSN numeric(25,0) NULL,
    BackupSizeInBytes bigint NULL,
    SourceBlockSize int NULL,
    FileGroupID int NULL,
    LogGroupGUID uniqueidentifier NULL,
    DifferentialBaseLSN numeric(25,0) NULL,
    DifferentialBaseGUID uniqueidentifier NULL,
    IsReadOnly bit NULL,
    IsPresent bit NULL

if @mssqlver>=2008
    alter table #Media add TDEThumbprint varbinary(32) NULL;

-- load info from backup file
insert into #media
exec('RESTORE FILELISTONLY FROM DISK = '''+@device+'''')

alter table #media add
    LocalName sysname,
    LocalPath nvarchar(1024)

/*
    select case when saf.status=2 then 'D' else 'L' end as t,*
    from master.dbo.sysaltfiles saf where dbid=db_id('utility')
*/

update #media set
    LocalName=saf.name,
    LocalPath=saf.filename
from #media m
join master.dbo.sysaltfiles saf
on  saf.dbid=@dbid and m.type=case when saf.status=2 then 'D' else 'L' end

if @@error!=0 goto ret

if @dbg=1
    select
        [Type],LogicalName,PhysicalName,
        LocalName,LocalPath
    from #media

select @sql='
    restore database [%db%]
    from disk = ''%device%'' with file=1, nounload,stats=10,replace
    ,recovery
'
exec sp__str_replace @sql out,'%db%|%device%',@db,@device
select @sql=@sql+'    ,move '''+isnull(LogicalName,'?LogicalName?')
                +''' to '''+isnull(LocalPath,'?LocalPath?')+''''+@crlf
from #media

if @doit=1
    begin
    exec(@sql)
    exec sp__prints '-- xp_cmdshell ''del "%s"''',@device
    end
else
    exec sp__printsql @sql
if @@error!=0
    begin
    if @dbg=1 exec sp__printsql @sql
    select @ret=-2
    goto ret
    end

/*
set @net_uid=coalesce(@net_uid,'') set @net_pwd=coalesce(@net_pwd,'')
if @simul=0 print @sql else print ''
if @simul=0 begin
    exec(@sql)
    set @err=0 set @err=@@error if @err!=0 goto ret
end
else print '*** SIMULATION *** (use @simul=0 to run really)'
if @net_uid<>'' or @net_pwd<>'' begin
    set @i=charindex('\\',@device)
    if @i<>0 set @i=@i+2
    set @i=charindex('\',@device,@i)
    set @cmd='net use '+substring(@device,1,@i-1)+' '+@net_pwd+' /user:'+@net_uid
    exec master..xp_cmdshell @cmd,no_output
end
--    se il db @name_db non esiste, allora esci dalla procedura
*/

goto ret

-- =================================================================== errors ==
err_mdb:    exec @ret=sp__err 'missing db; use CREATE DATABASE [%s]',@proc,@p1=@db
            goto ret
err_db:     exec @ret=sp__err 'cannot restore on current db itself',@proc
            goto ret
err_ver:    exec @ret=sp__err 'Tested only with MSSql 2K,2K5,2K8 (this is %d)',@proc
            goto ret
err_max:    exec @ret=sp__err 'This procedure manage only db of 1 data file and 1 logical file',@proc
            goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    restore a db from a device.
    The Divice can be a remote file. (not yet implemented)
    If begin with \\, can add usr/pwd separated by |.

Parameters
    @db     the name of database to owerwrite
    @device the backup source
            if %temp%, uses the autogenerated temp file name
    @opt    options
            run         modern version of old "doit"
            doit        execute instead of print code

Examples
    sp__restore ''testdb'',''%temp%\mybackup.bak''
'
ret:
return @ret
end -- [sp__restore]