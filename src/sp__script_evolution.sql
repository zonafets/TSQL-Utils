/*  leave this
    l:see LICENSE file
    g:utility
    k:extract,data,version,history,project,chart,graphics
    v:130823\s.zaglio: extract data for a graphics of history of develop
    t:sp__script_evolution 'utility',@dbg=1
*/
CREATE proc sp__script_evolution
    @grp sysname = null,
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
    @older_dt datetime,@newer_dt datetime,@days int

declare @tags table(obj sysname, tag varchar(8), val1 sysname,val3 sysname)
declare @nfo table(sdt sysname,dt datetime,comment nvarchar(max))
-- =========================================================== initialization ==

-- ======================================================== second params chk ==
if @grp is null goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==
-- extract all version/release and group tags
insert @tags
select obj,tag,isnull(cast(val1 as sysname),''),isnull(cast(val3 as sysname),'')
from fn__Script_info(default,'rvg',default)

-- remove objs of other groups than @grp
delete  tags
from @tags tags
join (
    select a.obj
    from @tags a
    join @tags b on a.obj=b.obj and b.tag in ('v','r')
    and isnumeric(cast(b.val1 as sysname))=1
    where a.tag='g' and cast(a.val1 as sysname)!=@grp
    ) todel on todel.obj=tags.obj

-- remove group and not tagged obj or not valid versions
delete @tags
where tag='g' or tag is null or isnumeric(val1)=0
or (isnumeric(val1)=1 and val1<'070101')

-- trim time
update @tags set val1=left(val1,6)

if @dbg>0
    select *,isnumeric(val1) isnum
    from @tags
    order by isnumeric(val1) desc,val1

-- calculate ranges
select
    @older_dt=convert(datetime,min(val1)),
    @newer_dt=convert(datetime,max(val1))
from @tags
select @days=datediff(d,@older_dt,@newer_dt)+1

-- group info
begin try
insert @nfo
select
    val1 as sdt,
    convert(datetime,val1,12) dt,
    ((select distinct obj+':'+val3+';'
      from @tags
      where val1=a.val1
      for xml path(''),type).value('.','nvarchar(max)'
    ))
from (select distinct val1 from @tags) a
end try
begin catch
select 'bad date' nfo,* from @tags where isdate(val1)=0
goto ret
end catch

if @dbg>0 select '@nfo' [@nfo],* from @nfo
-- sp__script_evolution 'utility',@dbg=1

-- show grouped history info
select
    cast(y as sysname)+'-'+
    substring('jan feb mar apr may jun jul aug sep oct nov dec ',(m*4)-3,3) dt,
    sum(changes) changes,
    (select distinct comment
     from @nfo
     where year(dt)=y and month(dt)=m
     for xml path(''),type).value('.','nvarchar(max)'
    ) comments
from (
    select year(b.dt) y,month(b.dt) m,isnull(changes,0) changes
    from (
        select dt,count(*) changes
        from @nfo
        --order by convert(datetime,sdt,112)
        group by dt
        ) a
    right join (
        select @older_dt+row-1 as dt
        from fn__range(1,@days,1)
        ) b
    on a.dt=b.dt
    ) a
group by y,m
order by y,m

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    extract data for a graphics of history of develop;
    can be used into Excel

Parameters
    [param]     [desc]
    @opt        options
    @grp        group name
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

Examples
    [example]
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
end catch   -- proc sp__script_evolution