/*  leave this
    l:see LICENSE file
    g:utility
    c:originally from www.sql.ru (mythical boys)
    v:131017\s.zaglio: about help and tests
    v:130803\s.zaglio: review
    v:100104\s.zaglio: save blob to a binary file
    t:sp__file_write_blob_test 100000000
    t:sp__file_write_blob_test @opt=small
    t:sp__file_write_blob_test @opt=big
    t:sp__file_write_blob_test @opt=huge
*/
CREATE proc [dbo].[sp__file_write_blob]
    @sqlfield nvarchar(4000) = null,
    @file sysname = null,
    @uid sysname = null,
    @pwd sysname = null,
    @blob varbinary(max) = null,
    @dbg bit=0
as
begin
set nocount on
declare
    @proc sysname,@ret int
select
    @proc=object_name(@@procid),@ret=0

declare
    @sql nvarchar(4000),@tmp nvarchar(512),
    @hr int,@obj int,@n int,@buffer int,
    @i int,@chunk varbinary(max)            -- split too big blob

if (nullif(@sqlfield,'') is null and @blob is null) or @file is null goto help
if @file like '%..%' goto err_wpro

exec sp__get_temp_dir @tmp out
select @file=replace(@file,'%temp%',@tmp)
if @dbg=1 exec sp__printf 'f:%s',@file

if @sqlfield!=''
    begin
    if left(@sqlfield,7)='select '
        begin
        select @sql='select @blob=('+@sqlfield+')'
        exec sp_executesql @sql,N'@blob varbinary(max) out',@blob=@blob out
        end
    else
        goto err_fld
    end

-- types: 1=adtypebinary
-- tsave: 2=adsavecreateoverwrite
select @obj=0,@buffer=64*1024--*1024
exec @hr=sp_oacreate 'adodb.stream', @obj output; if @hr!=0 goto err
exec @hr=sp_oasetproperty @obj, 'type', 1; if @hr!=0 goto err
exec @hr=sp_oamethod @obj, 'open'; if @hr!=0 goto err
select @n=datalength(@blob),@i=1
while (@i<@n)
    begin
    select @chunk=substring(@blob,@i,@buffer)
    exec @hr=sp_oamethod @obj, 'write', null, @chunk; if @hr!=0 goto err
    exec @hr=sp_oamethod @obj, 'flush'; if @hr!=0 goto err
    select @i=@i+@buffer
    end
exec @hr=sp_oamethod @obj, 'savetofile',null,@file,2; if @hr!=0 goto err
exec @hr=sp_oamethod @obj, 'close'; if @hr!=0 goto err
exec @hr=sp_oadestroy @obj;
select @obj=0
goto ret


-- =================================================================== errors ==

err:
declare @source nvarchar(255)
declare @description nvarchar(255)

exec @hr = sp_oageterrorinfo @obj, @source out, @description out
exec @ret=sp__err '%s;%s',@proc,@p1=@source,@p2=@description

if @obj!=0 exec sp_oadestroy @obj
goto ret

err_wpro:
exec @ret=sp__err 'worked protection against hackers :-)',@proc
goto ret

err_fld:
exec @ret=sp__err '@sqlfield must be a select',@proc
goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    save a blob to a file

See also
    * sp__file_read_blob

Parameters
    @sqlfield   providede for back compatibility,
                is the select the retrieve the blob
    @file       destination path (support %temp%)
    @uid        not used, provided for old compatibility
    @pwd        not used, provided for old compatibility
    @blob       direct data to save

'
select @ret=-1
goto ret

-- ===================================================================== exit ==
ret:
return @ret
end -- [sp__file_write_blob]