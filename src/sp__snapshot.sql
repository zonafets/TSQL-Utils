/*  leave this
    l:see LICENSE file
    g:utility
    v:111116\s.zaglio:removed use of fn__format
    v:111115\s.zaglio:create quickly a snapshot of a db
    t:sp__snapshot #,@dbg=1
*/
CREATE proc sp__snapshot
    @db sysname = null,
    @opt sysname = null,
    @dbg int=0
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
if @opt is null or @db is null goto help
if @db!='#'
and not exists(select null from master..sysdatabases where [name]=@db)
    goto err_ndb
if @db='#' select @db=db_name()

-- ============================================================== declaration ==
declare
    @sql nvarchar(max),
    @ndb sysname,@dt nvarchar(32),
    @psep nvarchar(4),@d datetime
create table #src(lno int identity, line nvarchar(4000))
create table #files(
    fileid int,
    [name] sysname,
    [path] nvarchar(512),
    [file] sysname,
    [ext] sysname
    )
-- =========================================================== initialization ==
select
    @psep=psep,
    @d=getdate(),
    @dt=convert(nvarchar(32),@d,8),
    @dt=convert(nvarchar(32),@d,12)+'_'+substring(@dt,1,2)+substring(@dt,4,2),
    @ndb=quotename(@db+'_'+@dt),
    @db=quotename(@db)
-- select *
from fn__sym()
-- ======================================================== second params chk ==
-- ===================================================================== body ==

-- collect files of db
select @sql='
insert #files(fileid,[name],[path],[file],ext)
select
    fileid,
    [name],
    substring([filename],1,(len([filename])-charindex(psep,reverse([filename])))+1) as [path],
    substring([filename],(len([filename])-charindex(psep,reverse([filename])))+2,128) as [file],
    substring([filename],(len([filename])-charindex(''.'',reverse([filename])))+2,128) as [ext]
from fn__sym(),'+@db+'..sysfiles sf
where status & 0x40 = 0;
update #files set [file]=substring([file],1,len([file])-len([ext])-1)
'
exec (@sql)
if @@error!=0 exec sp__printsql @sql

if not exists(select top 1 null from #files) goto err_nof

insert #src(line) select 'create database '+@ndb+' on ('
insert #src(line)
select '    name = '+[name]+', filename ='+crlf+
       '    '''+[path]+[file]+'_'+@dt+'.ss'' '+crlf
from fn__sym(),#files
insert #src(line) select ') as snapshot of '+@db

if @dbg>0
    exec sp__print_table '#src'
else
    exec @ret=sp__script_compile
if @@error=0 and @ret=0 exec sp__printf '-- drop database %s',@ndb

drop table #src
drop table #files

goto ret

-- =================================================================== errors ==
err_ndb: exec @ret=sp__err 'database "%s" not found',@proc,@p1=@db goto ret
err_nof: exec @ret=sp__err 'database "%s" with no files?',@proc,@p1=@db goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    create quickly a snapshot of a db into the same data directory
    with same name and extension YYMMDD_HHMMSS

Parameters
    @db     name of database (# for current)
    @dbg    debug options
            1 print sql instead of execute

Examples
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__snapshot