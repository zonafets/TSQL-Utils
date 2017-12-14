/*  leave this
    l:see LICENSE file
    g:utility
    r:131013\s.zaglio: show manual of object of search by keywords
    t:sp__man soap#call#web#service
*/
CREATE proc sp__man
    @what sysname = null,
    @opt sysname = null,
    @dbg int=0
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
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=nullif(@opt,''),
    @opt=case when @opt is null then '||' else dbo.fn__str_quote(@opt,'|') end
    -- @param=nullif(@param,''),

-- ============================================================== declaration ==
declare @sep char
-- =========================================================== initialization ==
if charindex('#',@what)>0 select @sep='#' else select @sep=','
-- ======================================================== second params chk ==
if nullif(@what,'') is null goto help

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

;with
    keywords(kword) as (
        select case when right(token,1)='s' then left(token,len(token)-1) else token end as token
        from fn__str_split(@what,@sep) a
    ),
    subkeys(obj_id,obj,match) as (
        select object_id as obj_id,name,1
        from sys.objects
        cross apply fn__str_split(name,'_')
        where token in (select kword from keywords)
    ),
    matches(obj,n) as (
        select
            o.name,
            case when charindex(kws.kword,definition)>1 then 1 else 0 end match
        from sys.objects o
        join sys.sql_modules m
        on o.object_id=m.object_id
        cross apply keywords kws
    ) -- select * from matches order by obj desc,n desc
-- select obj,n from matches union all select obj,1 from subkeys order by n desc
,
    matched(obj,n) as (
        select obj,sum(n) n
        from (
            select obj,n from matches
            union all
            select obj,1 from subkeys
            ) md
        group by obj
    )
select top 5 *
from matched
order by n desc

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    show manual of object or search by keywords

Notes
    actually not really uses k tag info but search into all definition

Parameters
    [param]     [desc]
    @what       specific object or list of keywords separated by # or comma
    @opt        (not used)
    @dbg        (not used)

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
end catch   -- proc sp__man