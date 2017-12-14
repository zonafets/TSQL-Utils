/*  leave this
    l:see LICENSE file
    g:utility
    v:130925\s.zaglio:test for fn__str_table
*/
CREATE proc sp__str_table_test
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
declare @test table(tst nvarchar(max),pos int,token nvarchar(4000))
insert @test select 'a|b|cc',0,'|'  -- main test
insert @test select 'a|b|cc',1,'a'  -- result
insert @test select 'a|b|cc',2,'b'  -- result
insert @test select 'a|b|cc',3,'cc' -- result
insert @test select 'a\n\nc',0,'\n' -- main test
insert @test select 'a\n\nc',1,'a'
insert @test select 'a\n\nc',2,''
insert @test select 'a\n\nc',3,'c'
insert @test select 'a b c  d',0,'' -- main test
insert @test select 'a b c  d',1,'a'
insert @test select 'a b c  d',2,'b'
insert @test select 'a b c  d',3,'c'
insert @test select 'a b c  d',4,''
insert @test select 'a b c  d',5,'d'
-- =========================================================== initialization ==
-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==
-- ===================================================================== body ==
select
    case when tst.token=t.token then 'ok' else 'ko' end sts,
    tst.tst,tst.pos,tst.token tst_token,t.token fn_result
into #t
from @test tst
full outer join (
    select t.tst,f.pos,f.token
    from @test t
    cross apply fn__str_table(tst,token) f
    where t.pos=0
    ) t
on tst.tst=t.tst and tst.pos=t.pos
where tst.pos!=0

exec sp__select_astext 'select * from #t order by 1,2,3'

exec sp__printf ''
exec sp__prints '8<'
exec sp__printf ''

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.


-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test for fn__str_table

Parameters
    [param]     [desc]
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
end catch   -- proc sp__str_table_test