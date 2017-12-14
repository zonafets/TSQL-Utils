/*  leave this
    l:see LICENSE file
    g:utility
    k:fast,debug,keyuboard,shortcut,
    v:130927\s.zaglio: better automation
    v:130922\s.zaglio: enable fast debug from ssms
    t:sp__script_debug 'select @@spid as spid,@@version ver,db_name() db'
    t:sp__script_debug ''
*/
CREATE proc sp__script_debug
    @script nvarchar(4000) = null,
    @opt sysname = null,
    @dbg int=0
as
begin -- no try because not useful with sp__err test for example
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
declare @test_id int,@crlf nvarchar(4),@sql nvarchar(max)
-- =========================================================== initialization ==
select @test_id=isnull(object_id('tempdb..#test'),0),@crlf=crlf from fn__sym()
-- print object_id('tempdb..#test')
-- ======================================================== second params chk ==
if @script is null and @test_id=0 goto help
-- =============================================================== #tbls init ==
-- ===================================================================== body ==

if not @script is null and @test_id!=0
    begin
    drop proc #test
    exec sp__printf '#test dropped'
    select @test_id=0
    end

if @script='' goto ret

if @test_id!=0
    exec #test
else
    begin
    if not object_id(@script) is null select @script='exec '+@script
    if not object_id(left(@script,charindex(' ',@script)-1)) is null
        select @script='exec '+@script

    select @sql ='create proc #test'+@crlf
                +'as'+@crlf
                +'begin'+@crlf
                +'set nocount on;'+@crlf
                +@script+@crlf
                +'end'
    begin try
    exec(@sql)
    exec sp__printf '#test created'
    exec #test
    end try
    begin catch
    exec sp__err null,'#test',@opt='ex'
    end catch
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    create or alter or delete or execute a proc #test with body @script

Notes
    Normally I associate this sp to shortcut CTRL+9 (in memory of
    litmus test - test of nine in italian).

Parameters
    [param]     [desc]
    @opt        (not used)
    @dbg        (not used)

Examples
    -- print help
    sp__script_debug
    -- init the debug
    sp__script_debug "select @@spid as spid,@@version ver,db_name() db"
    -- run it
    sp__script_debug
    -- drop #test
    sp__script_debug ""

'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- proc sp__script_debug