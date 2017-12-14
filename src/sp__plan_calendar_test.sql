/*  leave this
    l:see LICENSE file
    g:utility,plan
    k:plan,calendar,test
    r:121118\s.zaglio: test plan calendar functions
*/
CREATE proc sp__plan_calendar_test
    @opt sysname = null,
    @dbg int=0
as
begin
-- set nocount on added to prevent extra result sets from
-- interferring with select statements.
-- and resolve a wrong error when called remotelly
set nocount on
-- @@nestlevel is >1 if called by other sp

declare
    @proc sysname, @err int, @ret int,  -- @ret: 0=OK -1=HELP, any=error id
    -- error vars
    @e_msg nvarchar(4000),              -- message error
    @e_opt nvarchar(4000),              -- error option
    @e_p1  sql_variant,
    @e_p2  sql_variant,
    @e_p3  sql_variant,
    @e_p4  sql_variant

select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')

-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare
    @days nvarchar(24), @i int,@dt datetime,
    @end_declare bit

-- =========================================================== initialization ==
select
    @i=1,
    @days='',
    @end_declare=1

-- ======================================================== second params chk ==

-- =============================================================== #tbls init ==

-- ===================================================================== body ==
select
    cast(dbo.fn__plan_calendar('2012-01-01','') as varbinary(48)) as [12-01-01],
    cast(dbo.fn__plan_calendar('2012-31-01','') as varbinary(48)) as [12-31-01],
    cast(dbo.fn__plan_calendar('2012-01-02','') as varbinary(48)) as [12-01-02],
    dt
from
    dbo.fn__plan_dates(2012,dbo.fn__plan_calendar('2012-01-01',''))

while @i<13
    begin
    select
        -- 1st day of month
        @dt='2012-01-'+right('00'+cast(@i as varchar(2)),2),
        @days=dbo.fn__plan_calendar(@dt,@days)
        -- last day of month
    exec sp__printf 'dt=%s',@dt
    select
        @dt=case @i
            when 12
            then '2012-31-12'
            else convert(datetime,'2012-01-'+right('00'+cast(@i+1 as varchar(2)),2))-1
            end,
        @days=dbo.fn__plan_calendar(@dt,@days),
        @i=@i+1
    exec sp__printf 'dt=%s',@dt
    end

select cast(@days as varbinary(48)) days
select * from dbo.fn__plan_dates(2012,@days)

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- =================================================================== errors ==
/*
err:        exec @ret=sp__err @e_msg,@proc,@p1=@e_p1,@p2=@e_p2,@p3=@e_p3,
                              @p4=@e_p4,@opt=@e_opt                     goto ret

err_me1:    select @e_msg='write here msg'                              goto err
err_me2:    select @e_msg='write this %s',@e_p1=@var                    goto err
*/
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test plan calendar functions

Parameters
    [param]     [desc]

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__plan_calendar_test