/*  leave this
    l:see LICENSE file
    g:utility
    k:list,depend,object,dependencies,tree
    v:130521.1000\s.zaglio: print the tree of dependencies of an object
    t:sp__depends 'sp__script'
*/
CREATE proc sp__dependent
    @obj sysname = null,
    @level int = null,
    @opt sysname = null,
    @dbg int=0
as
begin try
/*
    originally from
      http://stackoverflow.com/questions/379649/
           t-sql-puzzler-crawling-object-dependencies
*/
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
    @crlf nvarchar(2),
    @txt nvarchar(max),
    @sub sysname

-- =========================================================== initialization ==
select
    @level=isnull(@level+1,0),
    @crlf=crlf
from fn__sym()

-- ======================================================== second params chk ==
if @obj is null goto help

-- =============================================================== #tbls init ==
if object_id('tempdb..#deptree') is null
    create table #deptree(id int identity,lv int,obj sysname)

-- ===================================================================== body ==

-- print replicate(' ',@level) + @obj
insert #deptree values(@level,@obj)

declare cs cursor local for
    select
        distinct c.name
    from dbo.sysdepends a
        inner join dbo.sysobjects b on a.id = b.id
        inner join dbo.sysobjects c on a.depid = c.id
    where b.name = @obj
open cs
while 1=1
    begin
    fetch next from cs into @sub
    if @@fetch_status != 0 break
    -- if already marked, skip to avoid max recurse error
    if not exists(select top 1 null from #deptree where obj=@sub)
        exec sp__dependent @sub, @level
    end
close cs
deallocate cs

-- =============================================================== print tree ==

if @level=0
    begin
    select @txt=isnull(@txt+@crlf,'')+replicate(' ',lv)+obj
    from #deptree
    exec sp__printsql @txt
    end


-- ================================================================== dispose ==
dispose:
if @level=0 drop table #deptree

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    print the dependency tree of the object, without repeat already printed
    objects

Parameters
    [param]     [desc]
    @obj        the object where find dependencies
    @level      used internally
    @opt        options
    @dbg        not used

Examples
    sp__depends "sp__script"
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
end catch   -- proc sp__dependent