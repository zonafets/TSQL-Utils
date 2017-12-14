/*  leave this
    l:see LICENSE file
    g:utility
    v:090122\S.Zaglio: again quoting management and expanded @cmd to 4000 chars
    v:081124\S.Zaglio: managed names with [] that osql don't accept
    v:081114\S.Zaglio: now is indipendent from other my sp to allow simple trasport&run to remote server
    v:080916\S.Zaglio: a little modification moved @dbg as paramerter
    v:080806\S.Zaglio: added @db
    v:080429\S.Zaglio: added @uid & @pwd
    v:080429\S.Zaglio
    t: begin declare @r int exec @r=sp__test_server '10.0.0.228','dontexist' print @r end
    t: begin declare @r int exec @r=sp__test_server '.','master' print @r end ->1
    t: begin declare @r int exec @r=sp__test_server '.','moster' print @r end ->0
    t: begin declare @r int exec @r=sp__test_server '.','' print @r end ->0
*/
CREATE procedure [dbo].[sp__test_server]
    @svr_name sysname,
    @db sysname,
    @ping_method bit=0,  -- 0=osql 1=ping
    @uid sysname='sa',
    @pwd sysname='',
    @error nvarchar(4000)=null out,
    @dbg bit=0
as
BEGIN
set nocount on
declare @exists int
declare @crlf nchar(2)
SET @crlf=CHAR(13)+CHAR(10)
declare @cmd nvarchar(4000)
set @exists=0

set @svr_name=dbo.fn__sql_unquotename(@svr_name)
set @db=dbo.fn__sql_unquotename(@db)

if @ping_method=1 begin
    if @dbg=1 print 'ping method'
    CREATE TABLE #test_svr_temp ( pingResult SYSNAME NULL );
    set @cmd='ping '+@svr_name
    if @dbg=1 print @cmd
    INSERT #test_svr_temp
        EXEC master..xp_cmdshell @cmd
    IF EXISTS (
        SELECT 1
            FROM #test_svr_temp
            WHERE pingResult LIKE '%TTL%'
        ) set @exists=1
    IF @dbg=1 SELECT * FROM #test_svr_temp
    DROP TABLE #test_svr_temp;
    end -- ping method
else
    begin -- osql method
    if @dbg=1 print 'osql method'
    IF EXISTS(SELECT 1 FROM dbo.sysobjects WHERE [ID] = OBJECT_ID('#temp1') AND type = ('U')) drop table #temp1
    CREATE TABLE #temp1 (dbname SYSNAME NULL );
    set @cmd='osql -S%svr_name% -dMaster -U%uid% -P%pwd% -Q"SELECT [Name] FROM sysdatabases where [name]=''%db%''"';
    set @cmd=replace(@cmd,'%svr_name%',@svr_name)
    set @cmd=replace(@cmd,'%uid%',@uid)
    set @cmd=replace(@cmd,'%pwd%',@pwd)
    set @cmd=replace(@cmd,'%db%',@db)
    if @dbg=1 print @cmd
    INSERT #temp1
        EXEC master..xp_cmdshell   @cmd
    IF EXISTS (
        SELECT 1
            FROM #temp1
            WHERE LTRIM(RTRIM(dbname)) = @db
        ) set @exists=1
    IF @dbg=1 SELECT * FROM #temp1
    if @exists=0 begin
        -- exec sp__readtable '#temp1', @error output
        declare @txt sysname
        declare @sql nvarchar(4000)
        declare cs_tmp_svr cursor local for select dbname from #temp1
        open cs_tmp_svr
        while (1=1)
            begin
            fetch next from cs_tmp_svr into @txt
            if @@error != 0 or @@fetch_status != 0 break
            if coalesce(@error,'')<>'' set @error=@error+@crlf
            set @error=@error+@txt
            end  -- while
        close cs_tmp_svr
        deallocate cs_tmp_svr
        DROP TABLE #temp1
        end -- readtable
    end -- osql method
return @exists
end