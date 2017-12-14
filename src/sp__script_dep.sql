/*  leave this
    l:see LICENSE file
    g:utility,script
    v:110324\s.zaglio: show also inverse list
    v:110315\s.zaglio: show dependencies of an object
    t:sp__script_dep 'sp__script_dep'
    t:sp__script_dep 'tids',@opt='uses'
*/
CREATE proc sp__script_dep
    @obj sysname = null,
    @level int = null,
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
select @level=isnull(@level,1)
-- ============================================================== declaration ==
declare
    @drop bit
-- =========================================================== initialization ==
-- select -- insert before here --  @end_declare=1
-- ======================================================== second params chk ==
if @obj is null or @level>1 goto help

if object_id('tempdb..#dep') is null
    create table #dep(
        id int identity,
        uses bit,
        obj sysname,
        buildin sysname null,
        usr sysname null,
        comment sysname null,
        [level] int
        )
else
    select @drop=0

-- ===================================================================== body ==
-- sp__script_dep 'sp__script_dep'
if charindex('|uses|',@opt)=0
    insert into #dep(uses,obj,buildin,usr,comment,[level])
    select distinct
        0 as uses,
        object_name(dep.depid) as require,
        convert(sysname,tag.val1) as buildin,
        convert(sysname,val2) as usr,
        convert(sysname,val3) as comment,
        1 as [level]
    -- select top 10 * from sysdepends dep
    from sysdepends dep --sys.sql_dependencies
    cross apply fn__script_info(object_name(depid),'v',default) tag
    where id=object_id(@obj)
    and tag.row=0
    order by 1
else
    insert into #dep(uses,obj,buildin,usr,comment,[level])
    select distinct
        1 as uses,
        object_name(dep.id) as require,
        convert(sysname,tag.val1) as buildin,
        convert(sysname,val2) as usr,
        convert(sysname,val3) as comment,
        1 as [level]
    -- select top 10 * from sysdepends dep
    from sysdepends dep --sys.sql_dependencies
    cross apply fn__script_info(object_name(depid),'v',default) tag
    where depid=object_id(@obj)
    and tag.row=0
    order by 1

if @drop is null
    begin
    select * from #dep order by id
    drop table #dep
    end

goto ret

-- =================================================================== errors ==
-- err_sample1: exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    show dependencies of an object
    If table #dep exists, will be filled to be used
    by caller:
        create table #dep(
            id int identity,
            uses bit,
            obj sysname,
            buildin sysname null,
            usr sysname null,
            comment sysname null,
            [level] int
            )

Parameters
    @obj    object name
    @level  show more levels of dependencies
            (today only 1 level is admitted)
    @opt    options
            uses    show objects that uses @obj and not that depends

Examples
    sp__script_dep ''sp__script_dep''
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_dep