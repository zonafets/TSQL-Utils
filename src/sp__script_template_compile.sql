/*  leave this
    l:see LICENSE file
    g:utility
    v:130728\s.zaglio: compile #tpl into #tpl_clp
*/
create proc sp__script_template_compile
    @tpl binary(20) = null,
    @start varchar(16),
    @scissors nvarchar(32),
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
    @bos sysname,               -- begin of section
    @lo_lno int,@hi_lno int     -- low and high line number

-- =========================================================== initialization ==
-- ======================================================== second params chk ==
if @tpl is null goto help
-- =============================================================== #tbls init ==
-- ===================================================================== body ==

-- compile #tpl into #tpl_cpl
while 1=1
    begin
    -- search for session begin
    select top 1 @lo_lno=lno+1,@bos=ltrim(rtrim(line))
    from #tpl
    where ltrim(rtrim(line)) like @start
    and lno>@hi_lno
    order by lno
    if @@rowcount=0 break
    -- search for session end
    select top 1 @hi_lno=lno-1
    from #tpl
    where lno>=@lo_lno
    and (ltrim(rtrim(line)) like @start
    or ltrim(rtrim(line)) like @scissors)
    order by lno
    if @@rowcount=0 select @hi_lno=max(lno) from #tpl
    select @bos=ltrim(rtrim(left(@bos,charindex(':',@bos)-1)))
    insert #tpl_cpl select @tpl,@bos,@lo_lno,@hi_lno
    end


-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    compile #tpl into #tpl_clp

Parameters
    [param]     [desc]
    #tpl        template source
    #tpl_clp    table with compiled data
    @opt        options (not used)
    @dbg        not used
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
end catch   -- proc sp__script_template_compile