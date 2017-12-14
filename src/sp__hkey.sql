/*  leave this
    l:see LICENSE file
    g:utility
    k:horizontal,keys,
    r:130929\s.zaglio: convert a list of keys in horizontal
    t:sp__hkey_test
*/
CREATE proc sp__hkey
    @column nvarchar(4000) = null,
    @hkey nvarchar(max) = null out,
    @opt sysname = null,
    @dbg int=0
as
begin try
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

declare @data nvarchar(max),@sep char,@nolist bit

-- =========================================================== initialization ==

select @column=nullif(@column,''),@sep='|',@nolist=charindex('|nolist|',@opt)

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if @column is null goto help

-- =============================================================== #tbls init ==
create table #tmp(ukey sysname)
-- ===================================================================== body ==

select @column='insert into #tmp select * from ('+@column+') a'
exec sp__printf '%s',@column
exec(@column)

select @data=
 stuff(
    (select @sep + ukey
    from #tmp
    for xml path(''), type
    ).value('(./text())[1]','nvarchar(max)')
  , 1, len(@sep), '')

select @hkey=replace(@data,@sep,'')

if @nolist=1 goto dispose
;with pieces(pos, start, [stop]) as (
  select
    cast(1 as int), cast(1 as int),
    charindex(@sep, @data)
  union all
  select
    cast(pos + 1 as int), cast([stop] + 1 as int),
    charindex(@sep, @data, [stop] + 1)
  from pieces
  where [stop] > 0
)
select -- row_number() over(order by (select 0)) row,
  pos,
  substring(@data, start,
            case when [stop] > 0 then [stop]-start else 4000 end
            ) as token,
  start,
  substring(@hkey,start-pos+1,10) ex
from pieces
option (maxrecursion 0)

-- ================================================================== dispose ==
dispose:
drop table #tmp

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    [write here a short desc]

Parameters
    [param]     [desc]
    @column     sql select of column key
    @opt        options
                nolist      do not output list os positions
    @dbg        1=last most importanti info/show code without execute it
                2=more up level details
                3=more up ...

Examples
    sp__hkey "select ukey from table"
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
end catch   -- proc sp__hkey