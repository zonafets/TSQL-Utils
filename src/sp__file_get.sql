/*  leave this
    l:see LICENSE file
    g:utility
    k:get,file,web,ftp,drive,disk,storage,download
    r:130906\s.zaglio: adapting to new fn__parse_url and sp__parse_url
    r:130829\s.zaglio: common call for more specified sp to read/download a file
    t:sp__file_get '%temp%\utility\index.txt'
*/
CREATE proc sp__file_get
    @uri nvarchar(2048) = null out,
    @var varbinary(max) = null out,
    @out nvarchar(1024) = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp

set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end
    -- @param=nullif(@param,''),

-- ============================================================== declaration ==
declare
    -- generic common
    @text bit,
    @i int,@n int,                         -- index, counter
    @sql nvarchar(max),                    -- dynamic sql
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @protocol sysname,
    @uid sysname,
    @pwd sysname,
    @host sysname,
    @port int,
    @path nvarchar(4000),
    @page nvarchar(4000),
    @temp nvarchar(512),
    @end_declare bit

-- =========================================================== initialization ==
exec sp__get_temp_dir @temp out
select
    @uri=replace(@uri,'%temp%',@temp),
    @text=charindex('|text|',@opt),
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if nullif(@uri,'') is null goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- sp__parse_url_test

select
    @protocol=protocol,
    @uid=uid,
    @pwd=pwd,
    @host=host,
    @path=path,
    @page=page
from fn__parse_url(@uri,default)

if @protocol='ftp' raiserror('ftp not yet supported',16,1)

if @protocol in ('http','https')
    begin
    if @dbg>0 exec sp__printf '-- getting via web'
    exec sp__web @uri,@rsp=@sql out
    -- select @sql=replace(@sql,@crlf+@crlf,@crlf)
    end

if @protocol='file'
    begin
    if @dbg>0 exec sp__printf '-- reading file %s',@uri
    -- not the faster but read 2MB in 7 seconds on localmachine

    select @sql=''
    if @text=1
        begin
        exec sp__file_read_stream @uri,@out=@sql out
        select @var=cast(@sql as varbinary(max))
        end
    else
        begin
        select @sql='select @var=BulkColumn '
                   +'from openrowset(bulk '''+@path+'\'+@page+''',single_clob)'
                   +' as x'
        exec sp_executesql @sql,N'@var image out',@var=@var out
        end

    select @n=len(@sql)
    if @dbg>0 exec sp__printf '-- loaded %d chars',@n
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    get a file from disk, web or ftp (todo) and store into @var or into
    the file specified by @out

Notes
    if executed from console, show the result, useful for tests

Parameters
    [param]     [desc]
    @uri        uniform resource identifier (see sp__parse_url_test)
    @var        image
    @opt        options
                text    inform the sp that the file is a text file
                        default is a binary file
    @dbg        info level

Examples
    sp__file_get "%temp%\utility\index.txt"
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end try

-- =================================================================== errors ==
begin catch
-- if @@trancount > 0 rollback -- for nested trans see style "procwnt"

exec @ret=sp__err @cod=@proc,@opt='ex'
return @ret
end catch   -- proc sp__file_get