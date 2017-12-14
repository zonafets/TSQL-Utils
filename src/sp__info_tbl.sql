/*  leave this
    l:see LICENSE file
    g:utility
    r:130426\s.zaglio: short comment
    t:sp__info_tbl rep05_delivery_notes
    t:sp__info_tbl rep06_delivery_notes_details,@dbg=1
    t:sp__info_tbl rep07_files,@dbg=1
*/
CREATE proc sp__info_tbl
    @tbl sysname = null,
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
    @i int,@n bigint,                       -- index, counter
    -- @sql nvarchar(max),                  -- dynamic sql
    -- options
    -- @sel bit,@print bit,                 -- select and print option for utils
    @col sysname,
    @len int,
    @typ sysname,
    @sql nvarchar(max),
    @oid int,
    @rows bigint,
    @d datetime,@ms int,
    @rf real,                               -- reference factor
    @end_declare bit

-- =========================================================== initialization ==
select
    -- @sel=charindex('|sel|',@opt),@print=charindex('|print|',@opt),
    -- @run=charindex('|run|',@opt)|dbo.fn__isjob(@@spid)
    --    |cast(@@nestlevel-1 as bit),        -- when called by parent/master SP
    @oid=object_id(@tbl),
    @end_declare=1

declare @cols table(
    id smallint identity primary key,
    tbl sysname,
    col sysname,
    typ sysname,
    ln int,
    n_distinct bigint,
    pctw tinyint,           -- whole effective occupation
    pctt tinyint,           -- text fields effective occupation
    ms int,
    idxs tinyint,           -- num of indexes where present
    ok_col bit default(1)
    )

-- if @print=0 and @sel=0 and dbo.fn__isConsole()=1 select @print=1

-- ======================================================== second params chk ==
if @tbl is null goto help

if @oid is null raiserror('table not found',16,1)

-- =============================================================== #tbls init ==

-- ===================================================================== body ==

-- count all records
select @rows=dbo.fn__count(@tbl)

insert @cols(tbl,col,typ,ln,n_distinct)
select @tbl,'*','*',0,@rows

insert @cols(tbl,col,typ,ln,n_distinct)
select @tbl,c.name,t.name,c.length,0
from syscolumns c
join systypes t
on c.xusertype=t.xusertype
where id=@oid
and iscomputed=0
order by colorder

update @cols set ok_col=0 where typ in ('*','image')

-- calculate rf
-- rf is a factor used to predict more correctly what happen if we change the
-- colum value with a int reference
-- (4*n.of.cols)/sum(size(n.of.cols))*100
select @rf=4.0*(select count(*) from @cols where ok_col=1 and ln>=4)
          /(select sum(ln) from @cols where ok_col=1 and ln>=4)

if @dbg>0 exec sp__printf '--rf:%d',@rf

declare cs cursor local for
    select col
    from @cols
    where ok_col=1
open cs
while 1=1
    begin
    fetch next from cs into @col
    if @@fetch_status!=0 break

    if @dbg>0 exec sp__printf '-- scanning col:%s',@col
    select @sql=null,@d=getdate()
    select @sql='select @n=count(*) '
               +'from (select distinct ['+@col+'] from ['+@tbl+']) a'
    exec sp_executesql @sql,N'@n bigint out',@n=@n out
    exec sp__elapsed @d out,@ms=@ms out
    update @cols set
        n_distinct=@n,
        pctw=cast((1.0*@n)/(@rows*1.0)*100 as int),
        ms=@ms
    where col=@col

    end -- cursor cs
close cs
deallocate cs

update @cols set
    pctw=(select sum(pctw)/count(*) from @cols where ok_col=1),
    pctt=(
        select sum(pctw)/count(*)
        from @cols
        where ok_col=1
        and (typ like '%char%' or typ like '%text%')
        ),
    ms=(select avg(ms) from @cols where ok_col=1)
where col='*'

-- correct with rf
update @cols set pctw=pctw+pctw*@rf,pctt=pctt+pctt*@rf

update c set idxs=i.n
from @cols c
join (
    select columnname col,count(*) n
    from fn__script_idx(@oid)
    group by columnname
    ) i on c.col=i.col

-- t:sp__info_tbl log_ddl,@dbg=1
if not object_id('tempdb..#sp__info_tbl_results') is null
    insert #info_tbl(tbl,col,typ,ln,n_distinct,pctw,pctt,ms,idxs)
    select tbl,col,typ,ln,n_distinct,pctw,pctt,ms,idxs from @cols
else
    begin
    select tbl,col,typ,ln,n_distinct,pctw,pctt,ms,idxs
    into #info_tbl
    from @cols
    exec sp__select_astext 'select * from #info_tbl order by typ'
    drop table #info_tbl
    end

-- ================================================================== dispose ==
dispose:
-- drop temp tables, flush data, etc.

goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    estime the redundancy of data of a table

Note
    will be excluded computed and image columns
    How read results
    pctw    is the percentage of whole data effectively used
    pctt    is the percentage of only text data but effectively used
    ms      is the time required to distinct data;
            in the row * is the average of all rows and can be used
            to estime the access time per rows where calculate the pctw
            to predict how we can gain after a normalization/aggregation
    NB1:    the redundancy is vertical and do not consider couple; so a
            waste of a single column can be normal if is coupled with an other;
            for example the bill address can redundant alone but correct if
            coupled with the ship address
    NB2:    the pct above 100% are normals because is considered an index
            called referential index that predict the replacement of a value
            with its index; so if pctw/pctt will be above than 100, normally
            mean that the table is already normalized

Parameters
    @tbl        table name
    @opt        options
    #info_tbl   if present fill this table instead of print values
                create table #info_tbl(
                    tbl sysname,
                    col sysname,            -- * is about all columns of table
                    typ sysname,
                    ln int,
                    n_distinct bigint,
                    pctw tinyint,           -- whole effective occupation
                    pctt tinyint,           -- text fields effective occupation
                    ms int,
                    idxs tinyint            -- num of indexes where present
                    )

Examples
    sp__info_tbl log_ddl
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
end catch   -- proc sp__info_tbl