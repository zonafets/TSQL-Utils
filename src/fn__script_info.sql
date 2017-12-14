/*  leave this
    l:see LICENSE file
    g:utility,script
    todo:manage multiline tags
    v:140124.1000\s.zaglio:removed limits near comment parse
    v:131103.1000\s.zaglio:adapted to new fn__script_info_tags
    v:130925\s.zaglio:a bug near with (...datalength('|')/2...)
    v:130907\s.zaglio:adapted to fn__script_into_tags
    v:130528\s.zaglio:removed dep from fn__str_table_fast and fn__comments
    v:130523.1200\s.zaglio:a bug when @objs was null and added xt fld and minor other
    v:130522\s.zaglio:no more compatible with mssql2k and optimized @obj to @objs
    v:120517\s.zaglio:removed from core group
    v:110629.1600\s.zaglio:added obj name to output and isolted from fn__ismssql2k
    v:110628\s.zaglio:added info about db trigger
    v:110627\s.zaglio:versioned
    r:110314\s.zaglio:added use of fn__script_info_tags
    r:100523\s.zaglio:a bug into row value
    r:100518\s.zaglio:managed line commented tags
    r:100417\s.zaglio:return info contained in tag of header
    c:##########################################################
    c:########## CORE FUNCTION, DO NOT CALL OTHERs #############
    c:##########################################################
    t:sp__usage 'fn__Script_info'
    t:
        -- multiline t (todo: manage this sub-tag)
        select * from fn__script_info('sp__style',default,default)
        select * from fn__script_info('fn__script_info',default,default)
        select * from fn__script_info('fn__script_info','rv',default)
        select * from fn__script_info('fn__script_info','r',0)
    t:select object_name(obj_id) name,* from fn__script_info(null,default,default)
    t:select object_name(obj_id) name,* from fn__script_info(null,'g',default)
    t:select * from dbo.fn__script_info('sp__script_group','vr',default)
    t:select * from dbo.fn__script_info('tr__script_trace_db','gvr',default)
    t:select * from dbo.fn__script_info('fn__script_info|sp__util_%',default,default)
    t:select * from dbo.fn__script_info('unknown',default,default)
    t:select * from dbo.fn__script_info('tst_test',default,default)
-- c:old style
*/
CREATE function [dbo].[fn__script_info](
    @objs sysname=null,                     -- all sp,fn,v,etc.
    @grps sysname=null,
    @lvl tinyint=null                       -- tag level (0 is top of group)
    )
returns @t table (
    obj_id int,
    obj sysname,
    xt varchar(2) null,
    tag nvarchar(4) null,                   -- l,g,v,d
    row smallint null,                      -- row of code
    val1 nvarchar(4000) null,               -- date,grp,deprecated
    val2 nvarchar(4000) null,               -- user,comment,2nd grp
    val3 nvarchar(4000) null                -- 3rd grp
)
as
begin

declare @r int,@id int,@buf nvarchar(max),@obj sysname
declare @objects table (id int,obj sysname,xt varchar(2),nfo nvarchar(256))

-- get objects
;with pieces(pos, start, [stop]) as (
  select 1, 1, charindex('|', @objs)
  union all
  select
    pos + 1,
    [stop] + 1,
    charindex('|', @objs, [stop] + 1)
  from pieces
  where [stop] > 0
),
splits as (
    select pos,
      substring(
        @objs,
        start,
        case when [stop] > 0 then [stop]-start else 4000 end
        ) as token
    from pieces
)
-- ;with splits as (select 1 as pos,@objs as token)
insert @objects (id,obj,xt)
select id,[name],xtype
from sysobjects o
cross apply splits
where (o.name like replace(token,'_','[_]') or @objs is null)
and xtype in ('P','V','TF','FN','IF','FI','TR')

union

-- special cases for db triggers
select object_id as id,[name],'TD'
from sys.triggers o
cross apply splits
where (o.name like replace(token,'_','[_]') or @objs is null)
and parent_id=0 -- means db trigger

-- fill tag info (one or more per object)
insert @t(obj_id,obj,xt,row,tag,val1,val2,val3)
select id,obj,xt,row,tag,val1,val2,val3
from @objects o
join sys.sql_modules m on m.object_id=o.id
cross apply fn__script_info_tags([definition],@grps,@lvl) t

-- add not tagged objects
if not @grps in ('d')
    insert @t(obj_id,obj,xt)
    select o.id,o.obj,o.xt
    from @objects o
    left join @t t on o.id=t.obj_id
    where t.obj_id is null

return
end -- fn__script_info