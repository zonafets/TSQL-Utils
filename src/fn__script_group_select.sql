/*  Leave this unchanged doe MS compatibility
    l:see LICENSE file
    g:utility,script
    d:130922\s.zaglio:fn__object_id
    v:130922.1101\s.zaglio:added lcl and replaced fn__str_parse
    v:130905,130730.1225,130726\s.zaglio:top0;wider nvarchar;a bug when empty group
    r:130708,130703,\s.zaglio: added exclusions;set of core
    r:130518\s.zaglio: select objects for scripting purpose
    t:
        select *
        from fn__script_group_select('utility',default,default,default,default)
        order by ord
    t:select * from fn__script_group_select('utility',default,default,'@s.zaglio',default)
    n:https://code.google.com/p/jquerycsvtotable/
    n:http://tablesorter.com/docs/
*/
CREATE function fn__script_group_select(
    @grp        sysname = null,
    @exclude    nvarchar(4000) = null,
    @include    nvarchar(4000) = null,
    @opt        varchar(256) = null,
    @dbg        int = 0
    )
returns @grp_objs table (
    obj_id int null,
    obj sysname,
    xt nvarchar(2) null,
    tag nvarchar(16) default('v'),
    aut sysname null,
    ver nvarchar(16) null,
    [des] sysname null,
    grp1 sysname null default(''),
    grp2 sysname null default(''),
    grp3 sysname null default(''),
    core bit default(0),                -- basic obj used to define others
    [drop] nvarchar(512) null,
    lcl sysname null,                   -- previous description or last change log
    ord int,
    match bit
    )
as
begin

declare
    @grp_setup sysname,@aut sysname

select @opt=dbo.fn__str_quote(coalesce(@opt,''),'|')

if charindex('|top0|',@opt)>0 return

if charindex('|@',@opt)>0
    select @aut=dbo.fn__str_between(@opt,'|@','|',default)

-- ============================================================= declarations ==

declare @crlf nvarchar(4)

declare @info table (
    obj_id int,obj sysname,tag nvarchar(4),xt varchar(2),
    val1 nvarchar(4000),val2 nvarchar(4000),val3 nvarchar(4000)
    )

declare @excludes table (obj sysname)

-- ===================================================================== body ==

select
    @crlf=crlf,
    @grp_setup=(select top 1 name
                from sys.objects
                where type='P' and name like '%'+@grp+'_setup'
               ),
    @exclude=isnull(@exclude+'|','')
            +'tr__script_trace|tr__script_trace_db|%[_]old'
from fn__Sym()

insert @excludes select token
from dbo.fn__str_table(@exclude,'|')

-- list all revisioned, groups objects info
insert @info(obj_id,obj,xt,tag,val1,val2,val3)
select
    si.obj_id,si.obj,si.xt,si.tag,
    isnull(si.val1,''),isnull(si.val2,''),isnull(si.val3,'')
-- select *
from dbo.fn__script_info(null,'rvg',0) si

-- removed excluded
delete nfo from @info nfo join @excludes ex on nfo.obj like ex.obj

-- apply group filter
delete obj
from @info obj
where obj.tag='g' and not @grp in (obj.val1,obj.val2,obj.val3)

-- insert remaining revisions with grp info
insert into @grp_objs(
    obj_id,obj,xt,tag,ver,aut,
    des,grp1,grp2,grp3
    )
select
    vr.obj_id,vr.obj,vr.xt,vr.tag,left(vr.val1,16) as ver,vr.val2 as aut,
    vr.val3, g.val1,g.val2,g.val3
from @info vr,@info g
where vr.tag in ('r','v') and g.tag='g' and vr.obj_id=g.obj_id
and (@aut is null or vr.val2=@aut)

-- insert @grp_objs(obj,aut) select 'qui',@aut goto ret

-- delete group info to avoid bad next joins
delete @info where tag='g'

-- deprecated of selected objects
insert into @grp_objs(obj_id,obj,tag,aut,ver,des)
select
    d.obj_id,d.obj,d.tag,d.val2,left(d.val1,16) as ver,
    case when isnumeric(d.val1)=1 then d.val3 else d.val1 end as des
-- select *
from fn__script_info(default,'d',default) d
join @grp_objs o on d.obj_id=o.obj_id

-- remove deprecated from objects to script if deprecated date is >
delete vr
from @grp_objs vr
join @grp_objs d on vr.obj=d.des
where vr.tag in('v','r') and d.tag='d'
-- and isnumeric(d.ver)=1 and d.ver>vr.ver

-- ============================================================ set the order ==

update objs set
    core=case when core.obj is null then 0 else 1 end,
    ord=
        case
        when not core.obj is null
        then core.ord
        else
            case
            when xt='TD' then 90                 -- trigger db
            when objs.obj=@grp_setup then 95     -- eXecute tag
            when xt='U'  then 100
            when xt='FN' then 200
            when xt='IF' then 210
            when xt='TF' then 220
            when xt='V'  then 300
            else 999
            end
        end,
    [drop]= case tag
            when 'd' then null
            else so.if_exists+@crlf+'    '+so.drop_script
            end
from @grp_objs objs
left join (
    select 'fn__script_sign' obj,   189 as ord  union   -- must be 1st
    select 'tids',                  192         union
    select 'flags',                 195         union
    select 'fn__sym',               198         union
    select 'fn__str_parse',         201         union
    select 'fn__str_parse_table',   204         union
    select 'fn__script_info_tags',  207         union
    select 'fn__script_info',       210         union
    select 'fn__script_drop',       213         union
    select 'fn__sysobjects',        216         union
    select 'fn__script_sysobjs',    219         union
    select 'fn__str_distance',      222         union
    select 'sp__deprecate',         225         union
    select 'sp__script_update',     228
    ) core on objs.obj=core.obj
join fn__sysobjects(default,default,'drop_script|if_exists|relaxed') so
on objs.obj_id=so.id

if charindex('|lcl|',@opt)>0
    update objs set lcl=lcl.val3
    from @grp_objs objs
    left join dbo.fn__script_info(null,'rv',1) lcl
    on objs.obj=lcl.obj
    where objs.tag in ('r','v')
/*
    t:
        select *
        from fn__script_group_select('utility',default,default,'lcl',default)
        order by ord
*/
ret:
return
end -- fn__script_group_select