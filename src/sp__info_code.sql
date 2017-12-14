/*  leave this
    l:see LICENSE file
    g:utility
    k:code,statistics,lines,per,x,day,period
    v:140115\s.zaglio: added help
    v:090906\s.zaglio: do some statistics about code
*/
CREATE proc sp__info_code
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
declare
    @eol nvarchar(4),@ln int,
    @app_dd money,@app_lns money,@utl_dd money,@utl_lns money,
    @app_n int,@utl_n int

-- =========================================================== initialization ==
-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1
-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==

-- ===================================================================== body ==

select @eol=char(13),@ln=len(@eol)

select @app_lns=sum((len(definition)-len(replace(definition,@eol,'')))/@ln)
from sys.sql_modules m
where not object_name(object_id) like '%[_][_]%'

select @utl_lns=sum((len(definition)-len(replace(definition,@eol,'')))/@ln)
from sys.sql_modules m
where object_name(object_id) like '%[_][_]%'

select @app_dd=sum(datediff(dd,create_date,modify_date)),@app_n=count(*)
-- select top 1 *
from sys.objects
join sys.sql_modules on sys.objects.object_id=sys.sql_modules.object_id
where not name like '%[_][_]%'
and [type]!='S'

select @utl_dd=sum(datediff(dd,create_date,modify_date)),@utl_n=count(*)
-- select top 1 *
from sys.objects
join sys.sql_modules on sys.objects.object_id=sys.sql_modules.object_id
where name like '%[_][_]%'
and [type]!='S'

select
    db_name() as db,
    @app_lns tot_app_lines,@app_dd tot_app_days,
    @app_lns/@app_dd app_lines_x_day,@app_n app_n_objs,
    cast(@app_lns/@app_n as int) app_lns_x_obj,
    @utl_lns tot_utl_lines,@utl_dd tot_utl_days,
    @utl_lns/@utl_dd utl_lines_x_day,@utl_n utl_n_objs,
    cast(@utl_lns/@utl_n as int) app_lns_x_obj,
    @utl_lns/@app_lns utl_lines_x_app

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    do some statistics about code (ecluding objects like table ofcourse)

Notes
    applications objects info (sp,fn,views, ecc that NOT likes "%__%"):
        tot_app_lines       total lines of code in the objects of application
        tot_app_days        sum of days from creation to last modifications of objs
        app_lines_x_day     average lines of code written per day
        app_n_objs          total number of objects of the application
        app_lns_x_obj       lines per object

    utilities objects info (sp,fn,views, ecc that likes "%__%"):
        tot_utl_lines
        tot_utl_days
        utl_lines_x_day
        utl_n_objs
        app_lns_x_obj

    utl_lines_x_app         relation between utilites and application

Parameters
    [param]     [desc]
    @opt        not used
    @dbg        not used

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
end catch   -- proc sp__info_code