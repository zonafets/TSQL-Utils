/*  leave this
    l:see LICENSE file
    g:utility
    k:binary
    r:130703\s.zaglio: compress #src content and replace it with hex code
*/
create proc sp__script_compress
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
    -- generic common
    @run bit,
    @i int,@n int,                      -- index, counter
    @sql nvarchar(max),
    @bin_sql varbinary(max),
    @line nvarchar(4000),
    @crlf nvarchar(2),
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    @crlf=crlf,
    @end_declare=1
from fn__sym()

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if object_id('tempdb..#src') is null goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- sp__script_group 'utility',@opt='bin'
select @n=count(*) from #src
exec sp__printf '-- %d lines in #src',@n
select @sql=
   stuff( (select @crlf+line
          -- select name
           from #src
           order by lno
           for xml path(''), type).value('.', 'nvarchar(max)')
        ,1,len(@crlf),'')
exec sp__printsql @sql
select @bin_sql=dbo.fn__compress(cast(@sql as varbinary(max)))
select @n=len(@bin_sql)
exec sp__printf '-- compressed size:%d',@n

truncate table #src
select @i=1
while (@i<len(@bin_sql))
    begin
    select @line=substring(dbo.fn__hex(substring(@bin_sql,@i,64)),3,128)
    insert #src(line) select @line
    select @i=@i+64
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    compress #src content and replace it with hex code

Parameters
    [param]     [desc]
    #src        the source code to compress
    @opt        options (not used)
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
end catch   -- proc sp__script_compress