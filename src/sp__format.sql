/*  leave this
    l:see LICENSE file
    k:format,test
    g:utility
    v:130624\s.zaglio: added 0<3 into test to allow out usage
    v:130510\s.zaglio: added sample for 0<n
    v:130423\s.zaglio: added output to #tests
    v:130329\s.zaglio: added sample for $<
    v:121122\s.zaglio: better help
    v:120821\s.zaglio: added 'DD/MM/YYYY HH:MM:SS'
    v:120809\s.zaglio: help and test for fn__format
    t:declare @d datetime select @d=getdate() exec sp__format @d, 'hhmm', 4
*/
CREATE proc sp__format
    @val sql_variant = null out,
    @fmt nvarchar(128) = null,
    @len int = null,
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
    @proc sysname, @err int, @ret int -- @ret: 0=OK -1=HELP, any=error id
select
    @proc=object_name(@@procid),
    @err=0,
    @ret=0,
    @dbg=isnull(@dbg,0),                -- is the verbosity level
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
-- ========================================================= param formal chk ==

-- ============================================================== declaration ==
declare @id int,@d datetime,@drop bit
-- drop table #tests
if object_id('tempdb..#tests') is null
    begin
    create table #tests(
        id int identity,
        val sql_variant,
        fmt nvarchar(128),
        ln int,
        expected nvarchar(4000),
        comment nvarchar(4000),
        result nvarchar(4000)
        )
    select @drop=1
    end
else
    select @drop=0
-- =========================================================== initialization ==
select @d='2012-08-21T16:28:11.000'
truncate table #tests
insert #tests select @d, 'hhmm', 4, '???', null, null
insert #tests select @d, 'yyyy', null, year(@d), null, null
insert #tests select '0930', 'hhmm', 4, '0930', null, null
insert #tests select @d, 'HHMMSS', 6, '162811', null, null
insert #tests select @d, 'DD/MM/YYYY HH:MM:SS', null, '21/08/2012 16:28:11', null, null
insert #tests select @d, 'YYYYMMDD_HHMMSS',null, '20120821_162811', null, null
insert #tests select @d, 'YYYYMMDDHHMMSS',null, '20120821162811', null, null
insert #tests select 'strip.n0t''AN: ;_chrs', 'AN', null, 'strip_n0t_AN____chrs', 'normalize light', null
insert #tests select '..strip.n0t''AN: ;_chrs..', 'ANs', null, 'strip_n0t_AN_chrs', 'normalize heavy', null
insert #tests select 123, '0<', 10, '0000000123', 'right padding with 0', null
insert #tests select 123.435, '0<2', 10, '0000012344', 'right padding with 0 and round and decimals', null
insert #tests select 123.435, '0<3', 10, '0000123435', 'right padding with 0 and round and decimals', null
insert #tests select 123, '$<', 10, '0000123.00', 'right money padding with 0', null
insert #tests select 'fn__format', '=<', 20, '==========fn__format', 'right padding with =', null
insert #tests select 'fn__format', '=< ', 20, '========= fn__format', 'right padding with = and a char before the name', null
insert #tests select '1239', '[eng]', null, 'One thousand two hundred thirty-nine', null, null
insert #tests select 1.104e+006, '0<', 10, '0001104000', 'right padding with 0', null
insert #tests select 'aàsòì°fd', '^', null, 'aa''so''i''.fd', 'transform accent', null
insert #tests select 'test', '^', null, 'test', null, null
insert #tests select '01021972', '@5678-34-12', null, '1972-02-01','relocate chars positions', null
insert #tests select '1234567890AB...', '@edcba0987654321', null, '...BA0987654321','relocate chars positions', null

update #tests set result=cast(dbo.fn__format(val,fmt,ln) as nvarchar(4000))

--insert #tests select 'REP05_DELIVERY', '|HIS*', null, 'HIS05_DELIVERY'
-- ======================================================== second params chk ==
if (@drop=0 or @val is null or @fmt is null) -- and @opt='||'
    goto help

-- ===================================================================== body ==

print dbo.fn__format(@val,@fmt,@len)

goto ret

-- =================================================================== errors ==
/*
err_sample1:
exec @ret=sp__err 'code "%s" not exists',@proc,@p1=@param
goto ret
*/
-- ===================================================================== help ==
help:
if @drop=0 goto skip
exec sp__usage @proc,'
Scope
    give help about fn__format and test backward compatibility

Notes
    formats covered by CONVERT like YYYYMMDD(112),YYMMDD(12) are not covered.

Parameters
    #tests  optional table where returns tests
            create table #tests(
                id int identity,
                val sql_variant,
                fmt nvarchar(128),
                ln int,
                expected nvarchar(4000),
                comment nvarchar(4000),
                result nvarchar(4000)
                )
    @val    is the value passed to be formatted and the result
    @fmt    is the format (see below)
    @len    depending on @fmt can be null or a generic length
    @opt    options(not used)

-- List of formats with example and expected results --
'

exec sp__select_astext '
    select
        id
        ,val
        ,fmt,ln
        ,expected
        ,result
        ,comment
    from #tests
    order by id
'

skip:
select top 1 @id=id from #tests where result!=expected and expected!='???'
if not @id is null
    exec @ret=sp__err 'wrong result from fn__format in test %d',@proc,@p1=@id
else
    select @ret=-1

if @drop=1 drop table #tests
-- select * from #tests

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__format