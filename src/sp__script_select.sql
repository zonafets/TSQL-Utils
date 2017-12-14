/*  Leave this unchanged doe MS compatibility
    l:see LICENSE file
    g:utility,script
    v:130518\s.zaglio: select objects for scripting purpose
    t:sp__script_select 'utility',@dbg=1
    t:sp__script_select 'utility'
    n:https://code.google.com/p/jquerycsvtotable/
    n:http://tablesorter.com/docs/
*/
CREATE proc [dbo].sp__script_select
    @grps_objs  nvarchar(4000) =null,
    @exclude    sysname =null,
    @include    sysname =null,
    @opt        sysname =null,
    @dbg        int     =0
as
begin try
set nocount on

declare
    @proc sysname,@ret int,
    @e_msg nvarchar(4000),@e_p1 sysname,@e_p2 sysname,
    @i int,@aut sysname -- derived parameter

select @proc=object_name(@@procid),@ret=0,
       @opt=dbo.fn__str_quote(coalesce(@opt,''),'|')

-- ================================================================ param chk ==

if @grps_objs is null goto help

if charindex('|@',@opt)>0
    select @aut=dbo.fn__str_between(@opt,'|@','|',default)

-- ============================================================= declarations ==
if object_id('tempdb..#info') is null
    -- this table will contain all objects to script
    create table #info (
        obj_id int,obj sysname,tag nvarchar(4),
        val1 nvarchar(4000),val2 nvarchar(4000),val3 nvarchar(4000)
        )

if object_id('tempdb..#grp_objs') is null
    create table #grp_objs(
        obj_id int null,
        obj sysname,
        xt nvarchar(2) null,
        tag nvarchar(16) default('v'),
        aut sysname,
        ver nvarchar(16) null,
        [des] sysname null,
        grp1 sysname null default(''),
        grp2 sysname null default(''),
        grp3 sysname null default(''),
        core bit default(0),        -- basic obj used to define others
        [drop] sysname null,
        ord int,
        match bit,
        )

-- ===================================================================== body ==

-- groups
insert #info(obj_id,obj,tag,val1,val2,val3)
select
    obj_id,obj,tag,
    cast(val1 as nvarchar(4000)),
    cast(val2 as nvarchar(4000)),
    cast(val3 as nvarchar(4000))
from dbo.fn__script_info(null,'g',default)

select 'grps' tbl,* from #info

-- apply group filter
if charindex(',',@grps_objs)>0
    delete obj
    from #info obj
    join dbo.fn__str_table(@grps_objs,',') fil
    on not token in (obj.val1,obj.val2,obj.val3)
    where obj.tag in ('v','r')

select 'grps filtered' tbl,* from #info

-- deprecated
insert #info(obj_id,obj,tag,val1,val2,val3)
select
    obj_id,obj,tag,
    cast(val1 as nvarchar(4000)),
    cast(val2 as nvarchar(4000)),
    cast(val3 as nvarchar(4000))
from dbo.fn__script_info(null,'d',default)

select 'deprecated' tbl,* from #info where tag='d'

-- version or release
insert #info(obj_id,obj,tag,val1,val2,val3)
select
    obj_id,obj,tag,
    cast(val1 as nvarchar(4000)),
    cast(val2 as nvarchar(4000)),
    cast(val3 as nvarchar(4000))
from dbo.fn__script_info(null,'vr',0)

select 'vr' tbl,* from #info where tag in ('v','r')

-- apply objects filter
if charindex('|',@grps_objs)>0
    delete obj
    from #info nfo
    where nfo.tag in ('r','v')
    and nfo.obj in (select token from dbo.fn__str_table(@grps_objs,'|'))

select 'vr filtered' tbl,* from #info where tag in ('v','r')

-- remove deprecated
delete vr
from #info vr
join #info d
on vr.obj=d.obj
where vr.tag in('v','r') and d.tag='d'

select 'vr - deprecated' tbl,* from #info where tag in ('v','r')

if @dbg>1 select * from #info

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    select objects to script; used by sp__script_group or other utility

Parameters
    @grps_objs  single group to script
                * the group is identified by tag G:
                * tag G support multiple groups separated by comma (",")
                * if contain a %, select names instead of group
                * if contain *, select also tables (with idxs,fkeys,trs)
                * SYS group, script S objects from fn__script_sysobjs
                * obj1|obj2|... direct script only obj1,obj2,...
                * grp1,grp2,... script objs that belongs to grp1 or ...

    @out    can be a path where out a single file or multiple files
            (extension is .sql or .htm depending on @opt)
            %grp% will be replaced with group name and create a unique file
            %obj% will replaced with obj name and create multiple files
            %t will be replaced with YYMMDD_HHMMSS
            %temp% will be replaced with windows user temp directory

    @opt    options
            html        out as html
                        (if out to multiple files, an index.htm will be created)
            prefix:path prefix path to link in index.html (prefix:./code_sql/)
            nochk       do not add check version
            bin         return results as compressed binary string
            @user       filter of objects of "user"

    @dbg    1 list selected objects and exit
            2 print and do not out to files

    @exclude is a "like" expression for post exclusion of objects
    @include is a "like" expression for pre inclusion of objects

Notes
    * an object that end with group name and "_setup", is considered the setup
      store procedure of the group, scripted 1st and executed immediatelly
    * if sp__script_store and sp__script_group are in R tag, cannot script
    * if object "%_%groupname%_setup" is in R, scripting is aborted

Examples
    -- normal use
    exec sp__script_group ''utility''

    -- special out to file with html format and index
    exec sp__script_group ''script'',@out=''%temp%\%obj%'',@opt=''index''

    -- replace macros
    create table #vars (id nvarchar(16),value nvarchar(4000))
    insert #vars select ''%license%'',''test replacements''
    exec sp__script_group ''script''
    drop table #vars

##########################
##
## SCRIPT GROUP STEPS
## ==================
##
## if script to console or into single file:
##   drop deprecated objects
##   check version
##     drop object
##     re-create
##
## is script "utility" group:
##   if exists uninstall db trigger
##   eventually re-create scripting core objects
##   drop deprecated objects
##   check version
##     drop object
##     re-create
##   if exists install db trigger and upgrade if necessary
##
########################################################

'
select distinct grp grps
from (
    select val1 grp from #info nfo where nfo.tag='g'
    union
    select val2 grp from #info nfo where nfo.tag='g'
    union
    select val3 grp from #info nfo where nfo.tag='g'
    ) grps
where not grp is null
order by 1

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
end catch   -- proc sp__script_select