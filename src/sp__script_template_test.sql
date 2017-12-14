/*  leave this
    l:see LICENSE file
    g:utility
    v:130802,130709\s.zaglio: test sp__script_template
*/
CREATE proc sp__script_template_test
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
    -- @i int,@n int,                      -- index, counter
    -- @sql nvarchar(max),                 -- dynamic sql
    -- options
    -- @sel bit,@print bit,                -- select and print option for utils
    @chk binary(16),@ochk binary(16),
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
        |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @ochk=0x978bf8a6061e18864a27b2c7594f901b,
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
-- if  @run=0 goto help

-- =============================================================== #tbls init ==
create table #src(lno int identity primary key,line nvarchar(4000))
create table #tpl(lno int identity primary key,line nvarchar(4000))
create table #tpl_sec(lno int identity,section sysname,line nvarchar(4000))
insert #tpl(line) select line from dbo.fn__ntext_to_lines('
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%header%:
    %detail%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
%details%:
line %n%
-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --
',0)
-- ===================================================================== body ==

exec sp__script_template '%details%','%detail%',@tokens='%n%',@v1=1
exec sp__script_template '%details%','%detail%',@tokens='%n%',@v1=2
exec sp__script_template '%header%'

-- sp__script_template_test
exec sp__md5 @chk out

exec sp__prints'template source'
exec sp__print_table '#tpl'
exec sp__prints'template rendered'
exec sp__print_table '#src'
exec sp__prints'results'
exec sp__printf 'template rendering original:%d',@ochk
exec sp__printf 'template rendering checksum:%d',@chk
-- sp__script_template_test
if @chk!=@ochk raiserror('test failed',16,1)
else exec sp__printf 'test passed'

-- ================================================================== dispose ==
dispose:
drop table #tpl
drop table #tpl_sec
drop table #src

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test sp__script_template functionalities

TODO:
    * simple test to console
    * mix a template that contain other template section to #src
      the section must contain another section (recursion test)
    * mix template and sections into #out
    * test tokens and #tpl_sec sections with CRLF

Parameters
    [param]     [desc]
    @opt        options
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
end catch   -- proc sp__script_template_test