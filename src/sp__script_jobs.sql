/*  leave this
    l:see LICENSE file
    g:utility
    v:140109\s.zaglio: problem of ending \ when scripted to file.
    v:090909\s.zaglio: from ms support
    -- single test
    exec sp__script_jobs
    exec sp__run_cmd 'type %temp%\%@@servername%_jobs.sql'
    exec sp__run_cmd 'del %temp%\%@@servername%_jobs.sql /q'

    -- out to temp table
    create table #src (lno int identity(10,10),line nvarchar(4000))
    exec sp__script_jobs @out='#src'
    select * from #src
    drop table #src

    -- out to specific dir
    declare @out sysname exec sp__get_env @out out,'allusersprofile'
    exec sp__script_jobs @out=@out,@dbg=1
    exec sp__run_cmd 'dir "%allusersprofile%"'
    exec sp__run_cmd 'del "%allusersprofile%\%@@servername%_jobs.sql" /q'
    -- exec sp__run_cmd 'del c:\temp\*.* /q /s /f'

*/
CREATE proc [dbo].[sp__script_jobs]
    @server nvarchar(30)=null,  -- server name to run script on. by default, local server.
    @out sysname=null,          -- can be #src or must terminate with .sql or \.
    @dbg bit=0
as
begin
set nocount on
if @server is null select @server=@@servername
--sp_oa params
declare @cmd nvarchar(255) -- command to run
declare @osqlserver int -- oa return object
declare @hr int -- return code

--user params
declare @filename nvarchar(200) -- file name to script jobs out

--sql dmo constants
declare @scripttype nvarchar(50)
declare @script2type nvarchar(50)
set @scripttype = '327'  -- send output to file, transact-sql, script permissions, test for existence, used quoted characters.
set @script2type = '3074'  -- script jobs, alerts, and use codepage 1252.

--set the following properties for your server
declare @tmp sysname
exec sp__get_temp_dir @tmp out
set @server =  lower(@server)
if right(@out,1)='\' select @out=left(@out,len(@out)-1)
if not @out is null and right(@out,4)!='.sql' and @out!='#src'
    select @filename=@out
else
    set @filename = @tmp
select @filename=@filename+'\'+@server+'_jobs.sql'

if @dbg=1 exec sp__printf 'out to:%s',@filename

--create the sqldmo object
exec @hr = sp_oacreate 'sqldmo.sqlserver', @osqlserver out

--set windows authentication
exec @hr = sp_oasetproperty @osqlserver, 'loginsecure', true

--connect to the server
exec @hr = sp_oamethod @osqlserver,'connect',null,@server

--script the job out to a ntext file
set @cmd = 'jobserver.jobs.script(' + @scripttype + ',"' + @filename +'",' + @script2type + ')'
create table #devnul (t ntext) insert into #devnul -- prevent output
exec @hr = sp_oamethod @osqlserver, @cmd
drop table #devnul

if @out='#src'
    begin
    exec sp__file_read @filename,'#src',@step=10
    select @cmd='del "'+@filename+'" /q'
    exec sp__run_cmd @cmd,@nooutput=1
    end

--close the connection to sql server
--if object is not disconnected, the processes will be orphaned.
exec @hr = sp_oamethod @osqlserver, 'disconnect'

--destroy object created.
exec sp_oadestroy @osqlserver
end -- [sp__script_jobs]