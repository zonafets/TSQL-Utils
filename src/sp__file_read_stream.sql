/*  leave this
    l:see LICENSE file
    g:utility
    v:130612\s.zaglio: @out to null if error
    v:130529\s.zaglio: added out to @out
    v:120406\s.zaglio: replaced #blob with #spfrsblob
    v:110921\s.zaglio: adapted to use of fn__ntext_to_lines
    v:110316\s.zaglio: adapted to new sp__write_ntext_to_lines #blob struct.
    v:100915\s.zaglio: added more help
    v:100603\s.zaglio: caos about line end
    v:100514.1436\s.zaglio: load txt file with different format (utf8, etc.)
    c:
        the filesystem object don't read utf8 txt files
        the type of cmd do not read utf8
        BULK INSERT #blob FROM 'file.txt' do not read utf8
    t:
        exec xp_cmdshell 'echo line 1 >%temp%\test.txt'
        exec xp_cmdshell 'echo line 2 >>%temp%\test.txt'
        create table #src(lno int identity,line nvarchar(4000))
        exec sp__file_read_stream '%temp%\test.txt',@out='#src',@dbg=1
        select * from #src order by lno
        drop table #src
*/
CREATE proc [dbo].[sp__file_read_stream]
    @path nvarchar(512)=null,
    @out nvarchar(max)=null out,
    @fmt sysname='utf-8',
    @ls int=-1,
    @uid sysname='null',
    @pwd sysname='null',
    @dbg bit=0
as
begin
set nocount on
declare
    @proc sysname,@tmp sysname,@ret int,
    @msg nvarchar(4000),--@buffer varchar(4000),
    @adodbstream int,
    @hr int,@size int,@ssize nvarchar(10),
    @chunk nvarchar(4000),
    @file sysname,@cmd sysname,
    @ptr varbinary(64),@n int,
    @end_declare bit

create table #spfrsblob(id int identity,blob ntext null)
insert #spfrsblob(blob) select ''
select top 1 @ptr=textptr(blob) from #spfrsblob where id=1
if @ptr is null goto err_ptr
-- drop table #buffer

select @proc=object_name(@@procid),@ret=0
if @path is null goto help

if @path like '%[%]temp[%]%'
    begin
    exec sp__get_temp_dir @tmp out
    select @path=replace(@path,'%temp%',@tmp)
    if @dbg=1 exec sp__printf 'path:%s',@path
    end

if @path like '%..%' goto err_wpro

select @size=4000

if @dbg=1 exec sp__printf 'init stream...'

select @ssize=convert(nvarchar(10),@size)
select @cmd='ADODB.Stream'
exec @hr = sp_oacreate @cmd, @adodbstream out
if @hr!=0 goto err
select @cmd='Type'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,2 -- text
if @hr!=0 goto err
select @cmd='charset'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,@fmt
if @hr!=0 goto err
select @cmd='LineSeparator'
exec @hr = sp_oasetproperty  @adodbstream ,@cmd,@ls
if @hr!=0 goto err
select @cmd='Open'
exec @hr = sp_oamethod  @adodbstream , @cmd, null
if @hr!=0 goto err
select @cmd='LoadFromFile'
exec @hr = sp_oamethod  @adodbstream , @cmd, null, @path
if @hr!=0 goto err
select @cmd='ReadText'

while (1=1)
    begin
    select @chunk=null
    exec @hr = sp_oamethod  @adodbstream , @cmd, @chunk out ,@size  -- with @size=.2 means read line
    select @n=len(@chunk)
    if @dbg=1 exec sp__printf 'chunk of %d:%s',@n,@chunk
    if @hr!=0 goto err
    if @n=0 or @chunk is null break
    updatetext #spfrsblob.blob @ptr null 0 @chunk
    end

if @out is null
    -- exec sp__write_ntext_to_lines @dbg=@dbg
    select line
    from dbo.fn__ntext_to_lines((select top 1 blob from #spfrsblob),0)
    order by lno
else
    begin
    if @out='#src'
        insert #src(line) select line
        from dbo.fn__ntext_to_lines((select top 1 blob from #spfrsblob),0)
        order by lno
    if @out='#out'
        insert #out(line) select line
        from dbo.fn__ntext_to_lines((select top 1 blob from #spfrsblob),0)
        order by lno
    if @out=''
        select top 1 @out=blob from #spfrsblob
    end -- out to know tables

-- drop table #blob

goto ret

help:
exec sp__usage @proc,'
Scope
    Import a text file

Parameters
    @path   source file path
    @out    can be #src or #out or nothing to out as recordset
            if is an empty string '''', out to @out itself
    @fmt    is the format of source file; by default is "utf-8"
            Other format are gived from constants acecpted by
            adodb.stream "charset" property.
    @ls     line separator (default -1 for CRLF else 10 for LF or 13 for CR)
            Unfortunatelly, MSSQL generates log that are incompatibile with
            this (or after too many tests I have not found one good)
            In that case the old xp_cmdshell "type ..." work well.

Notes
    BULK INSERT #blob FROM ''file.txt'' do not read utf8

See also
    * http://www.w3schools.com/ado/ado_ref_stream.asp
    * sp__write_ntext_to_lines
    * in MS2K5 can use
        select BulkColumn
        from openrowset(bulk ''file'',  single_clob) as x
            single_clob     text
            single_nclob    ntext   (not support utf8 and require specific unicode txt file)
            single_blob     image
    * ms-help://MS.SQLCC.v9/MS.SQLSVR.v9.it/tsqlref9/html/f47eda43-33aa-454d-840a-bb15a031ca17.htm

Example
    exec xp_cmdshell ''echo line 1 >%temp%\test.txt''
    exec xp_cmdshell ''echo line 2 >>%temp%\test.txt''
    create table #src(lno int identity,line nvarchar(4000))
    exec sp__file_read_stream ''%temp%\test.txt'',@out=''#src'',@dbg=1
    select * from #src order by lno
    drop table #src
'
select @ret=-1
goto ret

err:
declare @source nvarchar(255)
declare @description nvarchar(255)

exec @hr = sp_oageterrorinfo @adodbstream, @source out, @description out
exec @hr = sp_oadestroy @adodbstream
select @adodbstream=null,@out=null
exec @ret=sp__err 'ole error (%s;%s;%s)',@proc,@p1=@cmd,@p2=@source,@p3=@description
goto ret

err_wpro:   exec @ret=sp__err 'worked protection against hackers :-) ',@proc goto ret
err_ptr:    exec @ret=sp__err 'ptr get error',@proc goto ret

ret:
if @adodbstream!=0 exec @hr = sp_oadestroy @adodbstream
set nocount off
return @ret
end -- [sp__file_read_stream]