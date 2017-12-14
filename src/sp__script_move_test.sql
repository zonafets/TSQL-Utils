/*  leave this
    l:see LICENSE file
    g:utility
    v:130802\s.zaglio: test for sp__Script_move
*/
CREATE proc sp__script_move_test
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
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
        |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @end_declare=1

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
-- if  @run=0 goto help


-- =============================================================== #tbls init ==

-- ===================================================================== body ==

if not object_id('test_move') is null drop table test_move
if not object_id('test_move_copy') is null drop table test_move_copy
create table test_move(id int identity primary key,a int,b sysname)
insert test_move select 1,'one'
insert test_move select 2,'two'
select * into test_move_copy from test_move

exec sp__script_move
        't:test_move','test_move_copy',
        @where='1=1',
        @opt='back|move|nfo',
        @dbg=@dbg

-- ================================================================== dispose ==
dispose:
drop table test_move
drop table test_move_copy

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test for sp__Script_move

Parameters
    [param]     [desc]
    @opt        options
    @dbg
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
end catch   -- proc sp__script_move_test