/*  leave this
    l:see LICENSE file
    g:utility
    v:110523\s.zaglio: better debug and partial remake
    v:110415\s.zaglio: better debug
    v:100405\s.zaglio: added proc to sp__err
    v:100402\s.zaglio: removed out to xls on help
    v:100311\s.zaglio: deprecated output to xls,cvs because bcp out txt with xls extension and not binary xls
    v:100228\s.zaglio: more specific help and out to excel if file and with .xls
    v:090928\s.zaglio: added @unicode
    v:090925\s.zaglio: some auto corrections
    v:090123\s.zaglio: rewrited mixing from
    http://www.simple-talk.com/sql/t-sql-programming/reading-and-writing-files-in-sql-server-using-t-sql/
    v:080710/s.zaglio: write a table or a multi-string to a file (replace old sp__writetextfile)
    t:
        -- simple test
        declare @st sysname set @st='this is a test'+char(13)+char(10)+'hello line 2'
        exec sp__file_write '%temp%\test.txt',@text=@st
        exec sp__run_cmd 'type %temp%\test.txt',@dbg=1

        -- simple test with append
        exec sp__file_write '%temp%\test.txt',@text='opened for append',@addcrlf=1
        exec sp__file_write '%temp%\test.txt',@text='appended 1',@append=1,@addcrlf=1
        exec sp__file_write '%temp%\test.txt',@text='appended 2',@append=1,@addcrlf=1
        exec sp__run_cmd 'type %temp%\test.txt',@dbg=1
        exec sp__run_cmd 'del /q %temp%\test.txt',@dbg=1

        -- simple test with table
        create table #src (lno int identity(10,10),line nvarchar(4000))
        exec sp__script 'sp__script','#src'
        exec sp__file_write '%temp%\test.txt',@table='#src',@addcrlf=1,@dbg=1
        exec sp__run_cmd 'type %temp%\test.txt',@dbg=1
        drop table #src

        -- unicode test (don't work)
        declare @st sysname set @st='arabia ?????? lang?'
        exec sp__file_write '%temp%\test.txt',@text=@st
        exec sp__run_cmd 'type %temp%\test.txt',@dbg=1

*/
CREATE proc [dbo].[sp__file_write]
    @file nvarchar(1024)=null out,
    @text nvarchar(4000)=null,
    @table sysname =null,
    @addcrlf bit=0,
    @append bit=0,
    @unicode bit=0,
    @uid sysname=null,
    @pwd sysname=null,
    @dbg bit=0
as
begin -- proc
set nocount on
declare @proc sysname,@ret int,@n int,@i int
select @proc=object_name(@@procid),@ret=0
if @table is null and @text is null and @file is null goto help

-- sp__find '@table='
if not @table is null
and not @table in ('#src','#out','#ftpsrc','#htm','#html')
    goto err_tbl

if @dbg=1 exec sp__printf '-- %s ------------------------------',@proc

if coalesce(@file,'')='' goto err_file

declare
    @cmd nvarchar(4000), @crlf nchar(2), @row nvarchar(4000),
    @sql nvarchar(4000), @tmp sysname, @order nvarchar(512),
    @flds nvarchar(4000),@fldsc nvarchar(4000),
    @olecmd sysname,
    @source nvarchar(255),
    @description nvarchar(255),
    @helpfile nvarchar(255),
    @helpid int

select @crlf = crlf from fn__sym()

declare
    @objfilesystem int,@objtextstream int,@objerrorobject int,
    @strerrormessage nvarchar(1000),@hr int

if charindex('%temp%',@file)>0 begin
    exec sp__get_temp_dir @row out
    set @file=replace(@file,'%temp%',@row)
    if @dbg=1 print @file
end

if left(@file,1)='"' select @file=substring(@file,2,4000)
if right(@file,1)='"' select @file=left(@file,len(@file)-1)

if not @table is null
    begin
    if @table='#out'
        declare cs cursor local for
            select line
            from #out
            order by lno
    if @table='#src'
        declare cs cursor local for
            select line
            from #src
            order by lno
    if @table='#ftpsrc'
        declare cs cursor local for
            select line
            from #ftpsrc
            order by lno
    if @table='#htm'
        declare cs cursor local for
            select line
            from #htm
            order by lno
    if @table='#html'
        declare cs cursor local for
            select line
            from #html
            order by lno
    open cs
    end -- table source

/*
    see: http://msdn.microsoft.com/en-us/library/314cz14s(VS.85).aspx
    object.OpenTextFile(filename[, iomode[, create[, format]]])
    object:Required. Object is always the name of a FileSystemObject.
    filename:Required. String expression that identifies the file to open.
    iomode:Optional. Can be one of three constants: ForReading, ForWriting, or ForAppending.
    create:Optional. Boolean value that indicates whether a new file can be created if the specified filename doesn't exist. The value is True if a new file is created, False if it isn't created. If omitted, a new file isn't created.
    format:Optional. One of three Tristate values used to indicate the format of the opened file. If omitted, the file is opened as ASCII.
    Settings:The iomode argument can have any of the following settings:
         ForReading|1|Open a file for reading only. You can't write to this file.
         ForWriting|2|Open a file for writing.
         ForAppending|8|Open a file and write to the end of the file.
    The format argument can have any of the following settings:
         TristateUseDefault|-2|Opens the file using the system default.
         TristateTrue|-1|Opens the file as Unicode.
         TristateFalse|0|Opens the file as ASCII.
*/

select @strerrormessage='opening the file system object'
select @olecmd='scripting.filesystemobject'
execute @hr = sp_oacreate  @olecmd, @objfilesystem out
if @hr!=0 goto err_ole

if @append=0
    begin
    if @dbg=1 exec sp__printf 'creating file "%s" unicode(%d)',@file,@unicode
    select @olecmd='createtextfile'
    execute @hr = sp_oamethod   @objfilesystem   , @olecmd, @objtextstream out, @file,2,@unicode
    if @hr!=0 goto err_ole
    end -- crete
if @append=1
    begin
    if @dbg=1 exec sp__printf 'opening file "%s" unicode(%d)',@file,@unicode
    select @olecmd='opentextfile'
    execute @hr = sp_oamethod   @objfilesystem   , @olecmd, @objtextstream out, @file,8,@unicode,-1
    if @hr!=0 goto err_ole
    end -- oepn for append

while 1=1 begin
    if not @table is null begin
        fetch next from cs into @text
        if @@fetch_status!=0 break
    end
    /* -- old version:
    set @i=1
    set @n=dbo.fn__str_count(@text,@crlf)
    while (@i<=@n) begin
        set @row=dbo.fn__str_at(@text,@crlf,@i)
        set @cmd='echo '+@row+' 1>>"'+@file+'"'
        if @dbg=1 print @cmd
        exec master.dbo.xp_cmdshell @cmd,no_output
        set @i=@i+1
    end -- while
    */
    if @addcrlf=1 set @text=@text+@crlf
    select @olecmd='write'
    execute @hr = sp_oamethod  @objtextstream, @olecmd, null, @text
    if @hr!=0 goto err_ole
    if @table is null break
end -- while write table
select @olecmd='close'
execute @hr = sp_oamethod  @objtextstream, @olecmd
if @hr!=0 goto err_ole

if not @table is null begin
    close cs
    deallocate cs
end

execute sp_oadestroy @objtextstream
execute sp_oadestroy @objfilesystem
goto ret

-- =================================================================== errors ==

err_file:   exec @ret=sp__err 'file not specified',@proc goto ret
err_db:     exec @ret=sp__err '%s must specified after each from',@proc,@p1='%db%' goto ret
err_tbl:    exec @ret=sp__err 'accepted table are #out and #src',@proc goto ret
err_bcp:    exec @ret=sp__err 'error during generation of xls (%s)',@proc,@p1=@row goto ret
err_ole:    if @olecmd='scripting.filesystemobject'
                select @objerrorobject=@objfilesystem
            else
                begin
                select @objerrorobject=@objtextstream
                if @objerrorobject=0
                    select @objerrorobject=@objfilesystem
                end
            execute sp_oageterrorinfo  @objerrorobject,
                @source output,@description output,
                @helpfile output,@helpid output
            exec @ret=sp__err 'file:%s; cmd:%s; src:%s; desc:%s',
                              @proc,@p1=@file,@p2=@olecmd,@p3=@source,@p4=@description
            execute sp_oadestroy @objtextstream
            execute sp_oadestroy @objfilesystem
            goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    write or append to a text file a string or a table

Parameters
    @file       name of destination file
    @table        optional table name;
                can be only one of this tables:
                #src,#out,#ftpsrc,#htm,#html
    @text       optional line of text to write
    @addcrlf    0 by default, if 1 add a crlf to each line
    @append     0 by default, append to existing file instead of create
    @unicode    0 by default, 1 to write a unicode file instead of ANSI/ASCII
    @uid        not used
    @pwd        not used
'

ret:
return @ret
end -- sp__file_write