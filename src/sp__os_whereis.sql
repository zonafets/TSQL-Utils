/*  leave this
    l:see LICENSE file
    g:utility
    k:search,program,command,file,path,x86,any,system,64bit
    v:140107.1700\s.zaglio: search path of a program or command
    t:sp__os_whereis 'ftp.exe',@dbg=1
    t:sp__os_whereis 'winscp\winscp.com',@dbg=1
    t:sp__os_whereis 'winscp\nonscp.com',@dbg=1
    t:sp__os_whereis 'windows nt\accessories\wordpad.exe',@dbg=1
    t:xp_cmdshell 'C:\"Program Files"\"winscp"\"winscp.com"'
*/
CREATE proc sp__os_whereis
    @prg nvarchar(1024) = null out,
    @opt sysname = null,
    @dbg int = null
as
begin try
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
-- @@nestlevel is >1 if called by other sp (not correct if called by remote sp)

set nocount on

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    @err_msg nvarchar(2000)             -- used before raise

-- ======================================================== params set/adjust ==
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0)                 -- is the verbosity level

-- ============================================================== declaration ==

declare
    @path nvarchar(1024),@env nvarchar(1024),@i int,
    @tmp nvarchar(1024),@cmd nvarchar(1024),@envs nvarchar(4000)

-- =========================================================== initialization ==
if @prg is null goto help

-- ======================================================== second params chk ==
if left(@prg,1)='\' raiserror('path of program must be relative',16,1)

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- xp_cmdshell 'set'
-- xp_cmdshell 'dir %SystemRoot%\system32\ftp.exe'
-- xp_cmdshell 'dir %SystemRoot%\wow*'
select
    @envs='SystemRoot|ProgramFiles(x86)|ProgramFiles'

declare cs cursor local for
    select pos,token from dbo.fn__str_split(@envs,'|')
open cs
while 1=1
    begin
    fetch next from cs into @i,@env
    if @@fetch_status!=0 break

    -- init env and path
    select @path=case @i
                 when 1 then 'System32\'
                 else ''
                 end

    select @tmp=null
    exec sp__get_env @tmp out,@env
    if @tmp is null continue

    if right(@tmp,1)!='\' select @tmp=@tmp+'\'

    select @path=@tmp+@path+@prg
    select @cmd='dir "'+@path+'"'
    exec @ret=xp_cmdshell @cmd,no_output
    if @ret=0
        begin
        -- convert path for dir into path for execute
        select @path=replace(replace(@path,'\','"\"'),':"\"',':\"')+'"'
        break
        end

    end -- cursor cs
close cs
deallocate cs

select @prg=case @ret when 0 then @path else null end
if @dbg=1 exec sp__printf '@prg:%s',@prg

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    search into system and program paths the program and return the full path

Parameters
    [param]     [desc]
    @prg (out)  the name of command or of program to search
                out the full path
                NB: do not look into subdirectory, so the relative path
                    of the program must be specified (ex. winscp\winscp.com)
    @opt        not used
    @dbg        debug level
                1   basic info and do not execute dynamic sql
                2   more details (usually internal tables) and execute dsql
                3   basic info, execute dsql and show remote info

Examples
    @declare @prg nvarchar(4000)
    select @prg="ftp"
    exec sp__os_whereis @prg out
    if @prg is null raiserror(...)
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
end catch   -- proc sp__os_whereis