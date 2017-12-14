/*  leave this
    l:see LICENSE file
    g:utility
    k:ftp,manage,download,upload,delete,rename,ok,err
    v:130628\s.zaglio: bug near path
    v:130626\s.zaglio: bug near rename
    r:130614\s.zaglio: refined
    r:130302\s.zaglio: common ftp functionality
*/
create proc sp__ftp_manage
    @login nvarchar(1024) = null,
    @path nvarchar(1024) = null,
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
    @temp nvarchar(512),@cmd nvarchar(4000),
    @files bit,@ftpcmd bit,@ftpout bit, -- if relative table exists
    @flg_download smallint,@flg_upload smallint,
    @flg_delete smallint,@flg_ok smallint, @flg_err smallint,
    @end_declare bit

-- =========================================================== initialization ==
select
    @path=nullif(@path,''),
    @files=isnull(object_id('tempdb..#files'),0),
    @ftpout=isnull(object_id('tempdb..#ftpout'),0),
    @ftpcmd=isnull(object_id('tempdb..#ftpcmd'),0),
    @flg_download=[files.download],
    @flg_upload=[files.upload],
    @flg_delete=[files.delete],
    @flg_ok=[files.ok],
    @flg_err=[files.err],
    @end_declare=1
from flags

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if @login is null or @files=0 goto help

-- =============================================================== #tbls init ==
if @ftpcmd=0
    create table #ftpcmd(lno int identity primary key,line nvarchar(4000))
if @ftpout=0
    create table #ftpout(lno int identity primary key,line nvarchar(4000))

-- ===================================================================== body ==
if charindex('%temp%',@path)>0 -- if null invalidate all statement
    begin
    exec sp__get_temp_dir @temp out
    select @path=replace(@path,'%temp%',@temp)
    end

if @path!=''
    begin
    insert #ftpcmd select 'lcd "'+@path+'"'

    -- if nothing to upload, drop and create temp path
    if not exists(select top 1 null from #files where flags&@flg_upload!=0)
        begin
        select @cmd='del /s/q/f '+@path+
                    '&rmdir /s/q '+@path+
                    '&mkdir '+@path
        exec xp_cmdshell @cmd,no_output
        end
    end

-- default order: download, delete, rename, upload
insert #ftpcmd
select 'get "'+[key]+'"'
from #files
where flags&@flg_download!=0

insert #ftpcmd
select 'del "'+[key]+'"'
from #files
where flags&@flg_delete!=0

insert #ftpcmd
select 'ren "'+[key]+'" "'+[key]+
       case
       when flags&@flg_ok!=0 then '.ok'
       when flags&@flg_err!=0 then '.err'
       end+'"'
from #files
where flags&(@flg_ok|@flg_err)!=0

-- upload as temp files
insert #ftpcmd
select 'put "'+[key]+'" "tmp_'+[key]+'.tmp"'
from #files
where flags&@flg_upload!=0

-- rename uploaded temp
insert #ftpcmd
select 'ren "'+[key]+'" "tmp_'+[key]+'.tmp" "'+[key]+'"'
from #files
where flags&@flg_upload!=0

if @dbg in (0,2)
    begin
    exec @ret=sp__ftp @login
    if @dbg>1 exec sp__print_table '#ftpout'
    end
else
    exec sp__print_table '#ftpcmd'

-- ================================================================== dispose ==
dispose:
if @ftpcmd=0 drop table #ftpcmd
if @ftpout=0 drop table #ftpout

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    manage common ftp functionality as upload,download,rename,delete,etc.

Parameters
    #files      list of files according to sp__ftp
                settings flags field with flags.[files.*] we can simply
                manage files
    #ftpcmd     optional (caller must manage the fill/unfill)
    #ftpout     optional (caller must manage the cleaning)
    @login      login info according to sp__ftp @login
    @path       optional path where found files to download/upload
    @opt        options (not used)
    @dbg        1=show ftp cmds without execute it
                2=execute ftp cmds and show ftp out

Examples
    create table #files ....
    exec sp__ftp "127.0.0.1|usr|pwd","#files:*"
    update #files set flags=flags|flg.[files.del] from flags
    exec sp__ftp_manage "127.0.0.1|usr|pwd"     -- this will delete all files
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
end catch   -- proc sp__ftp_manage