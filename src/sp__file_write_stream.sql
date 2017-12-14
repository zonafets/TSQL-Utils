/*  leave this
    l:see LICENSE file
    g:utility
    v:121118\s.zaglio: added out option and info to skip BOM
    v:121026\s.zaglio: added @txt
    v:120723\s.zaglio: added html opt
    v:110621\s.zaglio: write a text file with different format
    t:
        declare @d datetime
        create table #src(lno int identity,line nvarchar(4000))
        insert #src select name+' '+name+' '+name+' '+name from syscolumns
        exec sp__elapsed @d out,'Init'
        exec sp__file_write_stream '%temp%\stream_test1.txt'
        exec sp__elapsed @d out,'after stream in utf8'
        exec sp__file_write '%temp%\stream_test2.txt',@table='#src',@addcrlf=1,@unicode=1
        exec sp__elapsed @d out,'after fileobject in unicode'
        exec master..xp_cmdshell 'del /q /f %temp%\stream_test1.txt',no_output
        exec master..xp_cmdshell 'del /q /f %temp%\stream_test2.txt',no_output
        drop table #src
*/
CREATE proc [dbo].[sp__file_write_stream]
    @path nvarchar(1024)=null,
    @fmt sysname        =null,
    @sep nvarchar(2)    =null,
    @txt nvarchar(max)  =null,
    @opt sysname        =null,
    @dbg int            =0
as
begin
set nocount on
declare @proc sysname,@ret int
select
    @proc=object_name(@@procid),@ret=0,
    @opt=dbo.fn__str_quote(isnull(@opt,''),'||')

if @fmt is null select @fmt='utf-8'
if @txt is null and @sep is null select @sep=crlf from fn__sym()

-- ============================================================= declarations ==
declare
    @tmp nvarchar(512),@cmd sysname,@hr int,@obj int,@line nvarchar(4000),
    @html bit,@src bit,@out bit,@ll int

-- ===================================================================== init ==

select
    @src=isnull(object_id('tempdb..#src'),0),
    @html=charindex('|html|',@opt),
    @out=charindex('|out|',@opt)

if @out=1 and object_id('tempdb..#out') is null goto err_out
if @html=1 and object_id('tempdb..#html') is null goto err_htm
if not @txt is null and not @sep is null goto err_txs

if @out=1 or @html=1 select @src=0      -- exclude #src of parent process

if @path is null and @src=0 and @html=0 and @out=0 and @txt is null
    goto help

if @path like '%[%]temp[%]%'
    begin
    exec sp__get_temp_dir @tmp out
    select @path=replace(@path,'%temp%',@tmp)
    if @dbg=1 exec sp__printf 'path:%s',@path
    end

if @path like '%..%' goto err_wpro

select @cmd='ADODB.Stream'
exec @hr = sp_oacreate @cmd, @obj out
if @hr!=0 goto err_ole
select @cmd='Type'
exec @hr = sp_oasetproperty  @obj ,@cmd,2 -- text
if @hr!=0 goto err_ole
select @cmd='charset'
exec @hr = sp_oasetproperty  @obj ,@cmd,@fmt
if @hr!=0 goto err_ole
select @cmd='Open'
exec @hr = sp_oamethod  @obj , @cmd, null
if @hr!=0 goto err_ole
-- UTFStream.Position = 3 'skip BOM
select @cmd='WriteText'
if not @txt is null
    exec @hr = sp_oamethod  @obj , @cmd, null, @txt, 0
else
    begin
    if @html=1
        begin
        select @ll=max(lno) from #html
        declare cs cursor local for
            select isnull(line,'')+case lno when @ll then '' else @sep end
            from #html
            order by lno
        end
    if @src=1
        begin
        select @ll=max(lno) from #src
        declare cs cursor local for
            select isnull(line,'')+case lno when @ll then '' else @sep end
            from #src
            order by lno
        end
    if @out=1
        begin
        select @ll=max(lno) from #out
        declare cs cursor local for
            select isnull(line,'')+case lno when @ll then '' else @sep end
            from #out
            order by lno
        end

    open cs
    while 1=1
        begin
        fetch next from cs into @line
        if @@fetch_status!=0 break
        -- default line separator keep data attached
        exec @hr = sp_oamethod  @obj , @cmd, null, @line, 0
        -- todo: remove bom
        -- objStream.Position = objStream.Size 'write at the beginning of the stream .ie. overwrite all
        if @hr!=0 goto err_ole
        end -- while of cursor
    close cs
    deallocate cs
    end

/*
UTFStream.Position = 3 'skip BOM

Dim BinaryStream As Object
Set BinaryStream = CreateObject("adodb.stream")
BinaryStream.Type = adTypeBinary
BinaryStream.Mode = adModeReadWrite
BinaryStream.Open

'Strips BOM (first 3 bytes)
UTFStream.CopyTo BinaryStream

'UTFStream.SaveToFile "d:\adodb-stream1.txt", adSaveCreateOverWrite
UTFStream.Flush
UTFStream.Close

BinaryStream.SaveToFile "d:\adodb-stream2.txt", adSaveCreateOverWrite
BinaryStream.Flush
BinaryStream.Close
*/
select @cmd='SaveToFile'
exec @hr = sp_oamethod  @obj , @cmd, null, @path, 2 -- adSaveCreateOverwrite
if @hr!=0 goto err_ole

goto ret

-- =================================================================== errors ==
err_wpro:
exec @ret=sp__err 'worked protection against hackers :-) ',@proc
goto ret

err_txs:
exec @ret=sp__err '@sep is not compatible with @txt',@proc
goto ret

err_ole:
declare @source nvarchar(255)
declare @description nvarchar(255)
exec @hr = sp_oageterrorinfo @obj, @source out, @description out
exec @hr = sp_oadestroy @obj
select @obj=null
exec @ret=sp__err 'ole error (%s;%s;%s)',@proc,@p1=@cmd,@p2=@source,@p3=@description
goto ret

err_htm:
exec @ret=sp__err '#html not found',@proc
goto ret

err_out:
exec @ret=sp__err '#out not found',@proc
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,N'
Scope
    write a text file, using adodb.stream to allow charset types

Parameters
    #src    source text lines (lno int identity,line nvarchar(4000))
    #out    alternative source test lines if "out" option is specified
    #html   alternative source text lines
    @fmt    is the format of source file (default is "utf-8")
            See list below
    @sep    line separator (default is CRLF)
    @txt    a single full text varable
    @opt    options
            html    use #html instead of #src as source
            out     use #out instead of #src as source

Example
    create table #src(lno int identity,line nvarchar(4000))
    insert #src select ''line one''
    insert #src select N''line with unicode Джон''
    insert #src select ''line tree''
    exec sp__file_write_stream ''%temp%\stream_test.txt'',@dbg=1
    exec master..xp_cmdshell ''type %temp%\stream_test.txt''
    exec master..xp_cmdshell ''del /q /f %temp%\stream_test.txt'',no_output
    drop table #src

    declare @txt as nvarchar(max)
    declare @i int select @txt=N''line with unicode Джон''+char(13)+char(10),@i=16
    while @i>0 select @txt=@txt+@txt,@i=@i-1
    print datalength(@txt)
    select @txt=''begin''+char(13)+@txt+''end''
    exec sp__file_write_stream ''%temp%\stream_test.txt'',@txt=@txt
    exec xp_cmdshell ''dir %temp%\stream_test.txt''
    -- check on server and then delete file

-- List of accepted formats --
'
create table #fmts(line sysname)
insert #fmts
    exec master..xp_regenumkeys 'HKEY_CLASSES_ROOT','MIME\Database\Charset'
exec sp__select_astext 'select line from #fmts order by 1'
drop table #fmts

select @ret=-1
goto ret

ret:
if @obj!=0 exec @hr = sp_oadestroy @obj
set nocount off
return @ret
end -- [sp__file_write_stream]