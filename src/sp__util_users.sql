/*  leave this
    l:see LICENSE file
    g:utility
    v:091216\s.zaglio: (in progress) utility for users management
    c:originally from Gregory A. Larsen
*/
create proc [dbo].[sp__util_users]
as
begin

set nocount on

-- Section 1: Create temporary table to hold databases to process

-- drop table if it already exists
if (select object_id('tempdb..##dbnames')) is not null
  drop table ##dbnames

-- Create table to hold databases to process
create table ##dbnames (dbname varchar(128))

-- Section 2: Determine what databases have orphan users

exec master.dbo.sp_MSforeachdb 'insert into ##dbnames select ''?'' from master..syslogins l right join [?]..sysusers u
on l.sid = u.sid
where l.sid is null and issqlrole <> 1 and isapprole <> 1
and not (u.name in (''INFORMATION_SCHEMA'',''guest'',''system_function_schema'',''sys'',''dbo''))
having count(*) > 0'



-- Section 3: Create local variables needed
declare @CNT int
declare @name char(128)
declare @sid  varbinary(85)
declare @cmd nchar(4000)
declare @c int
declare @hexnum char(100)
declare @db varchar(100)

-- Section 5: Process through each database and remove orphan users
select @cnt=count(*) from ##DBNAMES
While @CNT > 0
begin

-- get the name of the top database
  select top 1 @db=dbname from ##DBNAMES

-- delete top database
  delete from ##DBNAMES where dbname = @db

  select @db=quotename(@db)

-- Build and execute command to determine if DBO is not mapped to login
  set @cmd = 'select @cnt = count(*) from master..syslogins l right join ' +
             rtrim(@db) + '..sysusers u on l.sid = u.sid' +
             ' where l.sid is null and u.name = ''DBO'''
  exec sp_executesql @cmd,N'@cnt int out',@cnt out

-- if DB is not mapped to login that exists map DBO to SA
  if @cnt = 1
  begin
    print 'exec ' + @db + '..sp_changedbowner ''SA'''
    -- exec sp_changedbowner 'SA'
  end -- if @cnt = 1


-- drop table if it already exists
if (select object_id('tempdb..##orphans')) is not null
  drop table ##orphans

-- Create table to hold orphan users
create table ##orphans (orphan varchar(128))

-- Build and execute command to get list of all orphan users (Windows and SQL Server)
-- for current database being processed
   set @cmd = 'insert into ##orphans select u.name from master..syslogins l right join ' +
              rtrim(@db) + '..sysusers u on l.sid = u.sid ' +
              'where l.sid is null and issqlrole <> 1 and isapprole <> 1 ' +
              'and not u.name in (''INFORMATION_SCHEMA'',''guest'', ' +
              '''system_function_schema'',''sys'',''dbo'')'
   exec (@cmd)


-- Are there orphans
  select @cnt = count(*) from ##orphans

  WHILE @cnt > 0
  BEGIN

-- get top orphan
  select top 1 @name= orphan from ##orphans

-- delete top orphan
  delete from ##orphans where orphan = @name

-- Build command to drop user from database.
    set @cmd = 'exec ' + rtrim(@db) + '..sp_revokedbaccess ''' + rtrim(@name) + ''''
    print @cmd
    --exec (@cmd)


-- are there orphans left
    select @cnt = count(*) from ##orphans
  end --  WHILE @cnt > 0


-- are the still databases to process
select @cnt=count(*) from ##dbnames

end -- while @cnt > 0

-- Remove temporary tables
drop table ##dbnames, ##orphans

end -- proc