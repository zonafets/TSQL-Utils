/*  leave this
    l:see LICENSE file
    g:utility
    v:110726\s.zaglio:modified default name from %db%_%t in %db%
    v:110720\s.zaglio:added @include
    v:110719\s.zaglio:sp__backup_server
    t:sp__backup_server 'c:\backupSQL',@exclude='ReportServer$WEBAPP',@dbg=1
    t:xp_cmdshell 'dir c:\backupSQL'
*/
CREATE proc sp__backup_server
    @path       nvarchar(512) = null,
    @include    nvarchar(4000)= null,
    @exclude    nvarchar(4000)= null,
    @opt        sysname = null,
    @dbg        int = 0
as
begin
-- set nocount on added to prevent extra result sets from
-- interfering with select statements.
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname, @err int, @ret int -- standard API: 0=OK -1=HELP, any=error id
select  @proc=object_name(@@procid), @err=0, @ret=0, @dbg=isnull(@dbg,0)
select  @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare @db sysname,@device nvarchar(1024),@psep nvarchar(32)
create table #exclude ([name] sysname)
create table #include ([name] sysname)

-- =========================================================== initialization ==
select @psep=psep from fn__sym()

insert #exclude([name])
select '%tempdb%' union
select 'master' union
select 'msdb' union
select 'model' union
select token from dbo.fn__str_table(@exclude,'|')

if @include is null
    insert #include([name]) select '%'
else
    insert #include([name])
    select token from dbo.fn__str_table(@include,'|')

select db.[name]
into #dbs
-- select db.[name]
from master..sysdatabases db
join #include inc on db.[name] like inc.[name]
left join #exclude ex on db.[name] like ex.[name]
where [status] & (512|4096) = 0
and ex.[name] is null

drop table #exclude
/*
1 = autoclose (ALTER DATABASE)
4 = select into/bulkcopy (ALTER DATABASE tramite SET RECOVERY)
8 = trunc. log on chkpt (ALTER DATABASE tramite SET RECOVERY)
16 = torn page detection (ALTER DATABASE)
32 = loading
64 = pre recovery
128 = recovering
256 = not recovered
512 = offline (ALTER DATABASE)
1024 = read only (ALTER DATABASE)
2048 = dbo use only (ALTER DATABASE tramite SET RESTRICTED_USER)
4096 = single user (ALTER DATABASE)
32768 = emergency mode
4194304 = autoshrink (ALTER DATABASE)
1073741824 = cleanly shutdown
*/

if right(@path,1)!=@psep select @path=@path+@psep

-- ======================================================== second params chk ==
if @path is null goto help

-- ===================================================================== body ==

declare cs cursor local for
    select [name]
    from #dbs
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @db
    if @@fetch_status!=0 break

    if charindex('%db%',@path)=0 select @device=@path+'%db%'
    if charindex('.',@path)=0 select @device=@device+'.bak'

    if @dbg=0
        begin
        exec @ret=sp__backup @device out,@db,@opt='doit'
        if @ret=0 exec sp__printf '### %s backed up to "%s" ###',@db,@device
        end
    else
        exec @ret=sp__backup @device out,@db
    end -- while of cursor
close cs
deallocate cs

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    backup all online and non single user db of this server

Parameters
    @path       is the destination folder
    @include    list of db to include, separated by |. Can use %.
    @exclude    list of db to exclude, separated by |. Can use %.
                (%tempdb% are always excluded)
    @opt        options
                not used
    @dbg        1, show simulation

-- List of DB that will be saved --
'

exec sp__select_astext 'select * from #dbs order by 1'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__backup_server