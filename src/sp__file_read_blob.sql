/*  leave this
    l:see LICENSE file
    g:utility
    v:131017\s.zaglio: about help
    v:121021\s.zaglio: added @opt and option asm with help
    v:100915.1559\s.zaglio: added more help
    v:100228\s.zaglio: load binary file into temp table
    v:100104\s.zaglio: load a binary file a print inserts
    s:sp__write_ntext_to_lines for text blob
    c:originally from www.sql.ru (mythical boys)
    t:
        declare @path varchar(1024),@cmd sysname
        select @path='c:\windows\system32\findstr.exe'
        select @cmd='dir "'+@path+'"'
        exec sp__file_read_blob @path,'%temp%\test.bin',@uid='uid',@pwd='pwd'
    t:
        exec sp__run_cmd 'dir "%SystemRoot%\system32\cmd.exe"' -- 389120
        create table #blob (blob image)
        exec sp__file_read_blob 'c:\windows\system32\cmd.exe',@out='#blob.blob',@dbg=1
        select datalength(blob) from #blob
        drop table #blob
    t:exec sp__file_read_blob 'c:\windows\system32\cmd.exe',@opt='asm'

*/
CREATE proc [dbo].[sp__file_read_blob]
    @path sysname=null,
    @out sysname=null,
    @uid sysname='null',
    @pwd sysname='null',
    @opt sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare
    @proc sysname,@tmp sysname,@ret int,
    @buffer varbinary (8000),
    @msg nvarchar(4000),
    @adodbstream int,
    @hr int,@size int,@ssize nvarchar(10),
    @file sysname,@cmd sysname,
    @ptr varbinary(64),
    @asm bit,@n int,
    @end_declare bit

select
    @proc=object_name(@@procid),@ret=0,
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

if @path like '%..%' goto err_wpro

if @path is null goto help

select @tmp='##blob' --'[tmp'+replace(convert(sysname,newid()),'-','')+']'

if charindex('\',@out)>0 select @file=@out,@out=null
select @asm=charindex('|asm|',@opt)

if @out is null select @size=64
else select @size=8000

if @dbg=1 exec sp__printf 'init stream...'

select @ssize=convert(nvarchar(10),@size)
select @cmd='adodb.stream'
exec @hr = sp_oacreate @cmd, @adodbstream out
if @hr!=0 goto err
select @cmd='type'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,1
if @hr!=0 goto err
select @cmd='open'
exec @hr = sp_oamethod  @adodbstream , @cmd, null
if @hr!=0 goto err
select @cmd='loadfromfile'
exec @hr = sp_oamethod  @adodbstream , @cmd, null, @path
if @hr!=0 goto err
select @cmd='read'
exec @hr = sp_oamethod  @adodbstream , @cmd, @buffer out, @ssize
if @hr!=0 goto err

if @dbg=1 exec sp__printf 'read chunks...'

if @asm=0
    begin
    if @out is null
        begin
        print 'declare @ptr varbinary(64)'
        print 'create table '+@tmp+'(blob image)'
        print 'insert '+@tmp+' values('+dbo.fn__hex(convert(varbinary(64),substring(@buffer,1,@size)))+')'
        print 'select @ptr=textptr(blob) from '+@tmp
        end
    else
        begin
        if object_id('tempdb..#blob') is null goto err_tbl
        insert #blob values (@buffer)
        select @ptr=textptr(blob) from #blob
        end
    end -- !asm

select @n=0
while @buffer is not null
    begin
    select @cmd='read'
    exec @hr = sp_oamethod  @adodbstream , @cmd, @buffer out, @ssize out

    if @hr!=0 goto err
    -- print dbo.fn__hex(@ptr)
    if @asm=1
        begin
        if @n=0
            select @msg=dbo.fn__hex(convert(varbinary(64),
                                    substring(@buffer,1,@size)))+'\'
        else
            select @msg=substring(dbo.fn__hex(convert(varbinary(64),
                                              substring(@buffer,1,@size))),
                                  3,@size*2)+'\'
        exec sp__printf '%s',@msg
        end
    else
        begin
        if @out is null
            begin
            select @msg=dbo.fn__hex(convert(varbinary(64),
                                    substring(@buffer,1,@size)))+'\'
            print 'updatetext '+@tmp+'.blob @ptr null 0 '+@msg
            end
        else
            begin
            updatetext #blob.blob @ptr null 0 @buffer
            end
        end -- !asm
    select @n=@n+1
    end --loop

if @dbg=1 select datalength(blob) as dl, blob  as fdata from #blob

if @asm=0
    begin
    if @out is null
        begin
        if not @file is null
            begin
            select @msg ='exec sp__file_write_blob ''select top 1 blob from %s'','+
                        +'''%s'',@uid=%s,@pwd=%s'
            exec sp__printf @msg,@tmp,@file,@uid,@pwd
            select @msg='exec sp__run_cmd ''fc /b "%s" "%s"'''
            exec sp__printf @msg,@path,@file
            select @msg='exec sp__run_cmd ''dir "%s" & dir "%s"'''
            exec sp__printf @msg,@path,@file
            select @msg=null
            end
        print 'drop table '+@tmp
        end
    end -- !asm

goto ret

-- =================================================================== errors ==
err_wpro:   exec @ret=sp__err 'worked protection against hackers :-) ',@proc
            goto ret
err_tbl:    exec @ret=sp__err 'caller must create table #blob(blob image)',@proc
            goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,N'
Scope
    Load a file into a blob or script it.

Notes
    maybe today is better use one of:
    -- varbinary
    select BulkColumn from openrowset(bulk "%path%", single_blob) as blob
    -- varchar (until 2k12, does not support code page 65001(UTF-8 encoding))
    select BulkColumn from openrowset(bulk "%path%", single_clob) as blob
    -- nvarchar (require BOM)
    select BulkColumn from openrowset(bulk "%path%", single_nclob) as blob

See also
    * sp__file_read_stream

Parameters
    @path   source file
    @out    destination table.blob, file or null
            if null print the script to write
            else with sp__file_write_blob
    @uid    optional when @out is a file
    @pwd    optional when @out is a file
    @opt    options
            asm     script only hex code
    @dbg    1:debug info


Eample:
    create table #blob (blob image)
    exec sp__file_read_blob ''file_path'',@out=''#blob.blob''
    insert into #mytable(image_fld) select blob from #blob
    ...
'
select @ret=-1
goto ret

err:
declare @source nvarchar(255)
declare @description nvarchar(255)

exec @hr = sp_oageterrorinfo @adodbstream, @source out, @description out
exec @hr = sp_oadestroy @adodbstream
select @adodbstream=null
exec @ret=sp__err 'ole error (%s;%s;%s)',@proc,@p1=@cmd,@p2=@source,@p3=@description
goto ret

-- ===================================================================== exit ==
ret:
if @adodbstream!=0 exec @hr = sp_oadestroy @adodbstream
set nocount off
return @ret
end -- [sp__file_read_blob]