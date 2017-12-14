/*  leave this
    l:see LICENSE file
    g:utility
    v:091127\s.zaglio: added @print and use of sp__print_table
    v:090925\s.zaglio: some tips
    v:090911\s.zaglio: added help
    v:090909\s.zaglio: added special replacement for %@@servername% and %db_name()%
    v:081119\S.Zaglio: added tmp_table existance test and create
    v:081118\S.Zaglio: extended with parameters and external(online)file support
    v:081016\S.Zaglio: extended @cmd to 4000 chars
    v:080926\S.Zaglio: added @dbg param
    v:080806\S.Zaglio: added set nocount
    v:080704\S.Zaglio: run external command appendig result to temp table (name returned if null)
    t:sp__run_cmd 'dir "c:\"'
    t:sp__run_cmd 'dir %1','c:\',@print=1
    c:sample to run a command that need an external text file
    t:sp__run_cmd 'ftp -s:%file% 2>ftp_log.txt & type ftp_log.txt',@file='cmd1<br>cmd2',@dbg=1  --> generate file and replae %file% with name
    c:sample to write a batch to a file also to a remote net server
    t:sp__run_cmd @batch,@file='\\svr\dir\batch.cmd|net_uid|net_pwd',@dbg=1 --> generate batch file
    t:sp__run_cmd 'echo hello world!',@file='c:\windows\temp\test.txt',@dbg=1 --> generate batch file
*/
CREATE proc [dbo].[sp__run_cmd]
    @cmd varchar(4000)=null,
    @v1 sql_variant=null,        -- replace %1 or will be added to @cmd
    @v2 sql_variant=null,        -- replace %2
    @v3 sql_variant=null,        -- replace %3
    @v4 sql_variant=null,        -- replace %4
    @v5 sql_variant=null,        -- ...
    @v6 sql_variant=null,
    @v7 sql_variant=null,
    @v8 sql_variant=null,
    @v9 sql_variant=null,
    @file varchar(4000)=null,    -- txt content or path|uid|pwd
    @nooutput bit=0,
    @tmp_table sysname=null output,
    @nodrop bit=0,
    @print bit=0,
    @dbg bit=0
as
begin
set nocount on
if @dbg=1 exec sp__printf '-- sp__run_cmd ------------------------------'
declare
    @proc sysname,
    @msg nvarchar(4000),
    @end_declare bit

select
    @proc='sp__run_cmd'

if @cmd is null goto help

if not @v1 is null set @cmd=replace(@cmd,'%1',convert(varchar(4000),@v1))
if not @v2 is null set @cmd=replace(@cmd,'%2',convert(varchar(4000),@v2))
if not @v3 is null set @cmd=replace(@cmd,'%3',convert(varchar(4000),@v3))
if not @v4 is null set @cmd=replace(@cmd,'%4',convert(varchar(4000),@v4))
if not @v5 is null set @cmd=replace(@cmd,'%5',convert(varchar(4000),@v5))
if not @v6 is null set @cmd=replace(@cmd,'%6',convert(varchar(4000),@v6))
if not @v7 is null set @cmd=replace(@cmd,'%7',convert(varchar(4000),@v7))
if not @v8 is null set @cmd=replace(@cmd,'%8',convert(varchar(4000),@v8))
if not @v9 is null set @cmd=replace(@cmd,'%9',convert(varchar(4000),@v9))

declare @sql varchar(4000)
if @tmp_table is null begin
    set @tmp_table='[dbo].[tmp_'+convert(varchar(64),newid())+']'
    set @sql='create table '+@tmp_table+' (lno int identity, line nvarchar(4000))'
    if @dbg=1 exec sp__printf @sql
    exec(@sql)
    end
else
    begin
    if left(@tmp_table,1)='#' select @nodrop=1,@nooutput=1
    if dbo.fn__exists(@tmp_table,'U')=0
        begin
        set @sql='create table '+@tmp_table+' (lno int identity, line nvarchar(4000))'
        if @dbg=1 exec sp__printf @sql
        exec(@sql)
        end
    end

declare @crlf varchar(2) set @crlf=char(13)+char(10)
declare @file_name varchar(1024)
declare @uid sysname
declare @pwd sysname
declare @i int

set @cmd=replace(@cmd,'%@@servername%',@@servername)
set @cmd=replace(@cmd,'%db_name()%',db_name())

if charindex('%file%',@cmd)>0 begin
    exec sp__get_temp_dir @file_name out
    set @file_name='"'+@file_name+'\'+convert(varchar(64),newid())+'.txt"'
    set @cmd=replace(@cmd,'%file%',@file_name)
    set @file=replace(@file,'<br>',@crlf)
    if @dbg=1 exec sp__printf '@file=%s @text=%s',@file_name,@file
    exec sp__file_write @file_name,@text=@file,@dbg=@dbg
end
else begin
    if not @file is null begin
        set @file_name=dbo.fn__str_at(@file,'|',1)
        set @uid      =coalesce(dbo.fn__str_at(@file,'|',2),'')
        set @pwd      =coalesce(dbo.fn__str_at(@file,'|',3),'')
        if @uid<>'' or @pwd<>'' begin
            set @i=charindex('\\',@file_name)
            if @i<>0 set @i=@i+2
            set @i=charindex('\',@file_name,@i)
            set @sql='net use '+substring(@file_name,1,@i-1)+' '+@pwd+' /user:'+@uid
            set @sql='insert into '+@tmp_table+' exec master..xp_cmdshell '''+dbo.fn__inject(@sql)+''''
            if @dbg=1 exec sp__printf @sql
            exec(@sql)
        end
        exec sp__file_write @file_name,@text=@cmd,@dbg=@dbg
        if @uid<>'' or @pwd<>'' begin
            set @sql='net use '+substring(@file_name,1,@i-1)+' /delete'
            set @sql='insert into '+@tmp_table+' exec master..xp_cmdshell '''+dbo.fn__inject(@sql)+''''
            if @dbg=1 exec sp__printf @sql
            exec(@sql)
        end
        goto ret
    end -- batch write form
end -- if %file%

set @sql='insert into '+@tmp_table+' (line) values('''+dbo.fn__inject(@cmd)+''')'
if @dbg=1 exec sp__printf @sql
exec(@sql)
set @sql='insert into '+@tmp_table+' exec master..xp_cmdshell '''+dbo.fn__inject(@cmd)+''''
if @dbg=1 exec sp__printf @sql
exec (@sql)
if not @file_name is null begin
    set @cmd='del /q '+@file_name
    set @sql='insert into '+@tmp_table+' exec master..xp_cmdshell '''+dbo.fn__inject(@cmd)+''''
    if @dbg=1 exec sp__printf @sql
    exec (@sql)
    end
if @nooutput=0
    begin
    if @print=0
        begin
        select @sql='select * from '+@tmp_table+' order by lno'
        exec(@sql)
        end
    else
        exec sp__print_table @tmp_table
    end
if @nodrop=0 begin set @sql='drop table '+@tmp_Table exec(@sql) end
goto ret

help:
    select @msg ='Use:\n'
                +'\tsp__run_cmd ''dir %1'',''c:\''\n'
    exec sp__usage @proc,@msg
    select @msg=null
ret:
end