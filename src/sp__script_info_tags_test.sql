/*  leave this
    l:see LICENSE file
    g:utility
    k:extract,tags,test
    v:140117\s.zaglio: added special cases (as notes, see below)
    v:140114\s.zaglio: adapted to new info_Tags
    v:130926\s.zaglio: added dbg and test of parse of name
    v:130925\s.zaglio: test fn for all objects definitions
    v:130719\s.zaglio: test for fn__Script_info_tags
    r:130718\s.zaglio: test for fn__Script_info_tags
    o:130519\s.zaglio:sp__script_info_tags_test_old
    d:130519\s.zaglio:sp__script_info_tags_test_old
    t:sp__script_info_tags_test @dbg=1
*/
CREATE proc sp__script_info_tags_test
    @obj sysname = null,
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
declare @sql nvarchar(max),@grps sysname,@row int
-- =========================================================== initialization ==
select @obj=isnull(nullif(@obj,''),'%')
-- ======================================================== second params chk ==
-- =============================================================== #tbls init ==
create table #results(
    id int,
    obj sysname,
    xt sysname,
    sts varchar(2),
    err nvarchar(4000)
    )

-- ===================================================================== body ==
insert #results(id,obj,xt)
select object_id,[name],[type]
from sys.objects o
where [type] in ('P','V','TF','FN','IF','FI','TR')
and name like @obj
union
-- special cases for db triggers
select object_id,[name],'TD'
from sys.triggers o
where parent_id=0 -- means db trigger

declare cs cursor local for
    select r.obj,definition
    from #results r
    join sys.sql_modules m on m.object_id=r.id
open cs
while 1=1
    begin
    fetch next from cs into @obj,@sql
    if @@fetch_status!=0 break

    if @dbg>0 exec sp__printf '-- processing "%s"',@obj

    begin try
    select top 0 * into #t from fn__script_info_tags(@sql,@grps,@row)
    drop table #t
    update #results set sts='ok' where obj=@obj
    end try
    begin catch
    update #results set sts='ko',err=error_message() where obj=@obj
    end catch
    end -- cursor cs
close cs
deallocate cs

if @dbg>0 exec sp__printf '-- test parse of name'

declare cs cursor local for
    select r.obj,definition
    from #results r
    join sys.sql_modules m on m.object_id=r.id
open cs
while 1=1
    begin
    fetch next from cs into @obj,@sql
    if @@fetch_status!=0 break
    if @dbg>0 exec sp__printf '-- processing "%s"',@obj

    begin try
    declare @parsed sysname
    select @parsed=parsename(val3,1),@row=row
    from fn__script_info(@obj,'#',default) f
    where f.obj=@obj

    if @parsed!=@obj or @row<1
        update #results set sts='ko',err=isnull(err+';','')+'obj name wrong parse'
        where obj=@obj
    else
        update #results set sts='ok' where obj=@obj and left(sts,2)!='ko'
    end try
    begin catch
    update #results set sts='ko',err=error_message() where obj=@obj
    end catch
    end -- cursor cs
close cs
deallocate cs

if @dbg>0 exec sp__printf '-- test artefact cases'
if 1=(select count(*) from (
    select *
    from fn__script_info_tags('
                /*  leave this
                    l:
                    g:web
                    v:130515\s.zaglio:
                        /*test1*/
                    v:130129\s.zaglio: recreate procedure
                */
                create view vi
                as
                select 1 as one,2 two,3 three
                /* last but not least create */
                ...
                /* wrong comment or something inside a string
                ','#',default) rst
    union (
        select
            '#' as tag,
            257 as row,
            'create' as val1,
            'view' as val2,
            '[vi]' as val3,
            null as sts
        )
    ) cnt)
    insert #results(sts,obj,xt) select 'ok','_artefact case',''
else
    insert #results(sts,obj,xt) select 'ko','_artefact case',''

goto skip_cases

-- ============================================================ special cases ==
-- 140117\s.zaglio

select *
from fn__script_info_tags('
 /*  leave this
    l:
    g:web
    v:131212\author.1: comment
    v:131204\author.2: comment

    Non properly conformant comment

        print @@version
        print @@servername

*/
-- v1.0.090721/fname l. -- old style comment
-- v1.0.090603/fname l. -- old style comment
--                              another generic comment
CREATE PROCEDURE SP_SCRIPT_INFO_TAGS_TEST1
as
print 10
',default,default)

select *
from fn__script_info_tags('
/*  leave this
    l:see LICENSE file
    g:utility
    v:091216\s.zaglio:added @@servername
    v:091018\s.zaglio:
    Statistic of SQL-Server - System parameters for dynamic collection.

    @@cpu_busy/1000 - Returns the time in seconds that the CPU has spent working since SQL Server was last started.
    @@io_busy/1000  - Returns the time in seconds that SQL Server has spent performing
    */
    /*
    Daily Version.

    Output - Table TBL_SERVERSTATISTICS. A Table include Row per run a Procedure,except Saturday.
    -- select * from TBL_SERVERSTATISTICS
    -- select * from TBL_SERVERSTATISTICS_PRIOR
*/
CREATE PROCEDURE [dbo].[sp__perf_daily]  ( @BIT_DELETE_RESULTS BIT = 0 )
AS
print 10
',default,default)

skip_cases:

-- =========================================================== output results ==

exec sp__select_astext '
    select sts,obj,xt,err from #results order by sts
    '
exec sp__printf ''
exec sp__prints '8<'
exec sp__printf ''

if exists(select top 1 null from #results where sts='ko')
    raiserror('test failed',16,1)

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.


-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    test fn__script_info_tags for all objects definitions

Parameters
    [param]     [desc]
    @obj        filter for object(s) (default is %)
    @opt        (not used)
    @dbg        1 print object in process
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
end catch   -- proc sp__script_info_tags_test