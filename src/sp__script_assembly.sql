/*  leave this
    l:see LICENSE file
    g:utility
    r:121104\s.zaglio: compile behaviour change
    r:121028\s.zaglio: done the scripting
    d:121027\s.zaglio: sp__assembly
    r:121020\s.zaglio: refined
    r:100424\s.zaglio: utility for assembly integration
*/
CREATE proc sp__script_assembly
    @assembly sysname = null,
    @cs nvarchar(max) = null,   -- c# source
    @opt sysname = null,
    @dbg int = null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

declare
    @path nvarchar(1024),@cmd nvarchar(1024),
    @csc nvarchar(1024),@ext sysname,
    @dll nvarchar(1024),@src nvarchar(1024),
    @sql nvarchar(max),@tmp nvarchar(1024),
    @content varbinary(max),@i int,@crlf nvarchar(2),
    @asm_id int,@nets nvarchar(256)

declare @paths table(path nvarchar(1024),cod nvarchar(32))
create table #out(lno int identity,line nvarchar(4000))

select @crlf=crlf from fn__sym()

-- searcing compilers
select @cmd='dir "%SystemRoot%"\"Microsoft.NET"\csc.exe/s/b'
insert @paths(path) exec xp_cmdshell @cmd

select @nets='2.0|3.0|3.5|4.0|4.5'
-- 32
update p set cod=token+'x32'
from @paths p cross join dbo.fn__str_table(@nets,'|')
where path like '%\Framework\v'+token+'%\csc.exe'
-- 64
update p set cod=token+'x64'
from @paths p cross join dbo.fn__str_table(@nets,'|')
where path like '%\Framework64\v'+token+'%\csc.exe'

select top 1 @csc=path from @paths where charindex(cod,@opt)>0
if @csc is null
    begin
    select top 1 @csc=path from @paths where cod='2.0x32'
    if @dbg=1 exec sp__printf '-- default compiler:%s',@csc
    end
else
    if @dbg=1 exec sp__printf '-- forced compiler:%s',@csc

if @csc is null or isnull(@assembly,'')=''
    goto help

if exists(select * from sys.assemblies where name=@assembly) goto err_asm

-- compile into new assembly
exec sp__get_temp_dir @path out
select @tmp='sp__assembly_'+replace(cast(newid() as sysname),'-','_')
select @src=@path+'\'+@tmp+'.cs'
select @dll=@path+'\'+@tmp+'.dll'
if @dbg=1 exec sp__printf '-- src:%s, dll=%s',@src,@dll
exec sp__file_write_stream @src,@txt=@cs

-- select @cmd='cd "'+@path+'"&'+@csc ..
select @cmd=@csc+' /t:library /out:'+@dll+' '+@src
if @dbg!=0 exec sp__printf '-- cmd:%s',@cmd
insert #out exec @ret=xp_cmdshell @cmd
if @ret!=0 or exists(select null from #out where line like '%error%')
    goto err_csc

select @sql='create assembly %assembly% authorization [dbo] '
           +'from ''%dll%'' with permission_set = safe'
exec sp__str_replace @sql out,'%assembly%|%dll%',@assembly,@dll

exec(@sql)
if @@error!=0 goto err_cra

/*
select * from sys.assemblies
select * from sys.assembly_files
select * from sys.assembly_references
select      so.name, so.[type], schema_name(so.schema_id) as [schema],
            asmbly.name [assembly], asmbly.permission_set_desc, am.assembly_class,
            am.assembly_method
from        sys.assembly_modules am
inner join  sys.assemblies asmbly
        on  asmbly.assembly_id = am.assembly_id
        and asmbly.name not like 'microsoft%'
inner join  sys.objects so
        on  so.object_id = am.object_id
union
select      at.name, 'type' as [type], schema_name(at.schema_id) as [schema],
            asmbly.name, asmbly.permission_set_desc, at.assembly_class,
            null as [assembly_method]
from        sys.assembly_types at
inner join  sys.assemblies asmbly
        on  asmbly.assembly_id = at.assembly_id
        and asmbly.name not like 'microsoft%'
order by    4, 2, 1
*/
select @asm_id=assembly_id from sys.assemblies where name=@assembly
if @asm_id is null goto err_asm
select @content=content from sys.assembly_files  where assembly_id=@asm_id
exec('drop assembly '+@assembly)

select @i=1,@sql=null
while @i<=len(@content)
    select @sql=isnull(@sql+'\'+@crlf,'')
               +substring(dbo.fn__hex(substring(@content,@i,@i+64)),3,128),
           @i=@i+64
select @sql='create assembly '+@assembly+@crlf
           +'from 0x\'+@crlf+@sql+@crlf
           +'with permission_set = safe'+@crlf
exec sp__printsql @sql

/*
CREATE FUNCTION [fn_compress]           (
                 @compressedBlob varbinary(MAX))
            RETURNS varbinary(MAX)
            AS    EXTERNAL NAME %assembly%.%class%.%fn%;

select dbo.fn_compress(convert(varbinary(max),'test'))
*/


-- from http://www.codeproject.com/KB/database/blob_compress.aspx
/*
-- drop assembly utility_core
-- drop function fn__compress drop function fn__decompress
sp__script_assembly 'utility_core','
using System;
using System.IO;
using System.IO.Compression;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

public partial class utils
{
    // Setting function characteristics
    [Microsoft.SqlServer.Server.SqlFunction(IsDeterministic=true,
                                            DataAccess=DataAccessKind.None)]
    public static SqlBytes fn__compress(SqlBytes blob)
    {
        if (blob.IsNull)
            return blob;

        // Retrieving BLOB data
        byte[] blobData = blob.Buffer;

        // Preparing for compression
        MemoryStream compressedData = new MemoryStream();
        DeflateStream compressor = new DeflateStream(compressedData,
                                           CompressionMode.Compress, true);

        // Writting uncompressed data using a DeflateStream compressor
        compressor.Write(blobData, 0, blobData.Length);

        // Clossing compressor to allow ALL compressed bytes to be written
        compressor.Flush();
        compressor.Close();
        compressor = null;

        return new SqlBytes(compressedData);        // Returning compressed blob
    }

    public static SqlBytes fn__decompress(SqlBytes compressedBlob)
    {
        if (compressedBlob.IsNull)
            return compressedBlob;

        // Preparing to read data from compressed stream
        DeflateStream decompressor = new DeflateStream(compressedBlob.Stream,
                                           CompressionMode.Decompress, true);

        // Initializing variables
        int bytesRead = 1;
        int chunkSize = 10000;
        byte[] chunk = new byte[chunkSize];

        // Preparing destination stream to hold decompressed data
        MemoryStream decompressedData = new MemoryStream();

        try
        {
            // Reading from compressed stream
            while ((bytesRead = decompressor.Read(chunk, 0, chunkSize)) > 0)
            {
                // Writting decompressed data
                decompressedData.Write(chunk, 0, bytesRead);
            }
        }
        catch (Exception)
        {
            throw;                              // Nothing to do...
        }
        finally
        {
            decompressor.Close();               // Cleaning up
            decompressor = null;
        }
        return new SqlBytes(decompressedData);  // Returning a decompressed BLOB
    }
};
'
,@dbg=1
*/
dispose:
goto ret


-- =================================================================== errors ==
err_cra:
exec @ret=sp__err 'creating assembly',@opt='noerr'
goto ret

err_csc:
exec sp__print_table '#out'
exec @ret=sp__err 'compiler',@proc
goto ret

err_asm:
exec @ret=sp__err 'assembly already exists',@proc
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    compile a source stored into #src or from @file
    into a @file.dll

Notes
    * CLR must be active (see sp__util_advopt)
    * by default compile for .NET 2.0 32bit
    * actually only C# sources are considered

Parameters
    @assembly   assembly name
    @cs         is the c# source to compile and integrate
    @opt        options
                2.0x32  compile for .NET 2.0 32bit
                        others are: 3.0x32,3.5x32,4.0x32
                2.0x64  compile for .NET2.0 64bit
                        others are: 3.0x64,3.5x64,4.0x64
    @dbg        not used

'
exec sp__printf 'The C# compiler path is:%s\n',@csc
select @csc=@csc+' /?'
insert #out exec xp_cmdshell @csc
exec sp__print_table '#out'

-- ===================================================================== exit ==

ret:
drop table #out
-- remove temporary files
select @cmd='del /q '+@dll
exec xp_cmdshell @cmd,no_output
select @cmd='del /q '+@src
exec xp_cmdshell @cmd,no_output

return @ret
end -- sp__assembly