/*  leave this
    l:see LICENSE file
    g:utility
    k:table
    v:130729\s.zaglio:added tag t
    v:130327\s.zaglio:added @noidx and a bug near dropped index
    v:121004\s.zaglio:a bug near drop of disappeared cols
    v:121002\s.zaglio:added follow of symbolic src table
    v:120903\s.zaglio:added drop of constraints
    v:120903\s.zaglio:managed synonyms loop and no-out bug
    v:120827\s.zaglio:a bug near dst_db
    v:120801\s.zaglio:done and tested
    d:120727\s.zaglio:sp__table_align
    d:120727\s.zaglio:sp__script_copytable
    r:120727\s.zaglio:copy a table structure or align existing one
    t:sp__script_align_test
*/
CREATE proc sp__script_align
    @src    sysname = null,
    @dst    sysname = null,
    @opt    sysname = null,
    @dbg    int = 0
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
if (@src is null or @dst is null) and @opt='||' goto help

-- ============================================================== declaration ==
declare
    @svr sysname,
    @src_db sysname,@dst_db sysname,
    @src_sch sysname,@dst_sch sysname,
    @src_obj sysname,@dst_obj sysname,
    @xtype nvarchar(4), @cod sysname,
    @opt_src sysname,   -- common options for sp__script
    @crc int,
    @crlf nvarchar(2),
    @sql nvarchar(max),
    @from int,          -- from code
    @to int,            -- to code
    @src_id int,
    @dst_id int,
    @notrg bit,         -- do not replicate trigger
    @run bit,
    @noidx bit,         -- do not replicate indexes
    @end_declare bit

create table #src(lno int identity,line nvarchar(4000))
create table #src_src(lno int identity,line nvarchar(4000))
create table #src_def(  -- drop table #src_def
    xtype nvarchar(2),  -- type: see table below
    id int identity,
    rid int,            -- propert parent
    flags smallint,     -- flags depend on tid
    cod sysname,        -- object or property name
    val sql_variant,    -- value of property
    idx int,            -- relative source position start,
    [end] int           -- extra fld for end of code
    )
create index #src_def on #src_def(xtype,cod)

-- tables columns compare to know which add and drop
create table #cmp_col (src sysname null,dst sysname null,col_def nvarchar(512))
create table #const(col sysname,name sysname)

-- final table with info about differencies
create table #cmp(
    xtype nvarchar(2),
    cod sysname,
    src_crc int,
    dst_crc int,
    src_from int,
    src_to int
    )
create index #cmp on #cmp(xtype,cod)

-- =========================================================== initialization ==
select
    @notrg=charindex('|notrg|',@opt),
    @noidx=charindex('|noidx|',@opt),
    @run=charindex('|run|',@opt),
    @opt_src='noprop|nocmt'+case @notrg when 1 then '|notrg' else '' end,
    @crlf=crlf
from fn__sym()

-- try to replace local synonym
select @src=base_object_name from sys.synonyms where name=@src
select @dst=base_object_name from sys.synonyms where name=@dst

-- normalize src
select @svr=svr, @src_db=isnull(db,db_name()), @src_sch=sch, @src_obj=obj
from dbo.fn__parsename(@src,default,1)
if not @svr is null and @svr!=dbo.fn__servername(Null) goto err_svr

select @src=quotename(@src_db)+'.'+isnull(@src_sch,'')+'.'+@src_obj
select @src_id=object_id(@src)
if @dbg=1 exec sp__printf '-- src_db:%s, src:%s',@src_db,@src

if @src_id is null goto err_onf

if not @src_id is null and object_id(@src,'U') is null goto err_syn

-- 121002\s.zaglio: if @db!=db_name() goto err_db
-- 121002\s.zaglio: select @xtype=xtype from sysobjects where id=@obj_id
-- 121002\s.zaglio: if @xtype!='u' goto err_ntt

-- normalize dst
select @svr=svr,
       @dst_db=isnull(db,@src_db),
       @dst_sch=isnull(sch,@src_sch), @dst_obj=obj
from dbo.fn__parsename(@dst,default,default)
if not @svr is null goto err_svr

select @dst=quotename(@dst_db)+'.'+isnull(@dst_sch,'')+'.'+@dst_obj
select @dst_id=object_id(@dst)
if not @dst_id is null and object_id(@dst,'U') is null goto err_syn

-- some checks
if db_id(@dst_db) is null or db_id(@src_db) is null goto err_dnf
if @dst_db=@src_db and @dst_sch=@src_sch and @dst_obj=@src_obj goto err_obj

if @dbg=1 exec sp__printf '-- dst_db:%s, dst:%s',@dst_db,@dst

-- ======================================================== second params chk ==
-- ===================================================================== body ==

-- ============================================================ script source ==
exec @ret=sp__script @src,@opt=@opt_src
if @ret!=0 goto err_scr

-- alter to destination name
insert #src_src select replace(line,@src_obj,@dst_obj) from #src order by lno
update #src_def set cod=replace(cod,@src_obj,@dst_obj)
-- from - to
update src_def set [end]=isnull(b.idx-1,99999)
from #src_def src_def
left join #src_def b on src_def.id+1=b.id

-- prepare code for check
select top 100 percent
    d.xtype,d.cod,s.lno,s.line,checksum(line) crc
into #src_crc
from #src_src s
join #src_def d
on s.lno between d.idx and d.[end]
order by s.lno

-- calc crc of new
declare cs_src cursor local for
    select distinct xtype,cod,idx,[end] from #src_def
open cs_src
while 1=1
    begin
    fetch next from cs_src into @xtype,@cod,@from,@to
    if @@fetch_status!=0 break

    select @crc=null
    select @crc=isnull(tbl.crc^@crc,tbl.crc)
    from #src_crc tbl
    where xtype=@xtype and cod=@cod

    insert #cmp(xtype,cod,src_crc,src_from,src_to)
    select @xtype,@cod,@crc,@from,@to

    end -- cursor cs_src
close cs_src
deallocate cs_src

-- ================================================ script destination object ==

if not @dst_id is null
    begin
    truncate table #src_def
    truncate table #src
    exec @ret=sp__script @dst,@opt=@opt_src
    if @ret!=0 goto err_scr

    -- prepare code for check
    select top 100 percent
        d.xtype,d.cod,s.lno,s.line,checksum(line) crc
    into #dst_crc
    from #src s
    join (
        select -- a.id,b.id,
            a.xtype,a.flags,a.cod,
            a.idx as start,isnull(b.idx-1,99999) [end]
        from #src_def a
        left join #src_def b on a.id+1=b.id
    ) d
    on s.lno between d.start and d.[end]
    order by s.lno

    -- calc crc of new
    declare cs_dst cursor local for
        select distinct xtype,cod from #src_def
    open cs_dst
    while 1=1
        begin
        fetch next from cs_dst into @xtype,@cod
        if @@fetch_status!=0 break

        select @crc=null
        select @crc=isnull(tbl.crc^@crc,tbl.crc)
        from #dst_crc tbl
        where xtype=@xtype and cod=@cod

        update #cmp set dst_crc=@crc where xtype=@xtype and cod=@cod
        if @@rowcount=0
            insert #cmp(xtype,cod,dst_crc) select @xtype,@cod,@crc

        end -- cursor cs_dst
    close cs_dst
    deallocate cs_dst

    truncate table #src
    insert #src select 'use ['+@dst_db+'] '

    -- check if table is changed
    if exists(
            select null
            from #cmp
            where xtype='u' and src_crc!=dst_crc
            )
        begin
        select @sql=
        '
        -- compare fields
        insert #cmp_col
        select
            src.name src_col,dst.name dst_col,
            dbo.fn__sql_def_col(
                                c.tablename,null,
                                dbo.fn__str_quote(c.columnname,''[]''),
                                null,c.typename,
                                c.[length],c.[precision],c.scale,
                                c.allownulls,c.dridefaultname,
                                c.dridefaultcode,c.[identity],
                                c.iscomputed,c.computedtext,null/*chkname*/,
                                null/*chkcode*/,c.collation,null,null
            ) as line
        from (
            select name
            from [%src_db%]..syscolumns
            where id=%src_id%
            ) src
        full outer join (
            select name
            from [%dst_db%]..syscolumns dst
            where dst.id=%dst_id%
            ) dst
        on src.name=dst.name
        left join [%src_db%]..fn__script_col(%src_id%) c on c.columnname=src.name
        where 1=1
        and (src.name is null or dst.name is null)

        -- acquire dst constraints
        insert #const(col,name)
        select c.name col,object_name(d.constid,db_id(''%dst_db%'')) cnts
        from [%dst_db%]..sysconstraints d
        join [%dst_db%]..syscolumns c on c.id=%dst_id% and c.colid=d.colid
        where d.id=%dst_id%
        '
        exec sp__str_replace
                @sql out,
                '%dst%|%dst_db%|%src_obj%|%src_id%|%dst_id%|%src_db%',
                @dst,@dst_db,@src_obj,@src_id,@dst_id,@src_db
        if @dbg>0 exec sp__printsql @sql
        -- exec sp__printsql @sql
        exec(@sql)

        -- drop idx before columns to avoid column used problem

        -- drop pk if changed
        insert #src select ''
        insert #src select '-- drop pk if changed'
        insert #src
        select 'alter table '+@dst_obj+' drop constraint '+quotename(cod)
        from #cmp
        where src_crc!=dst_crc  -- nulls excluded
        and xtype in ('pk')

        -- drop index that not exists anymore
        insert #src select ''
        insert #src select '-- drop dest idx that not exists anymore'
        insert #src
        select 'drop index '+quotename(@dst_obj)+'.'+quotename(cod)
        from #cmp
        where src_crc is null
        and xtype in ('ix')

        insert #src select ''
        insert #src select '-- drop old constraints'
        insert #src
        select 'alter table '+@dst_obj+' drop constraint '+quotename(con.name)
        from #cmp_col col
        join #const con on con.col=col.dst
        where src is null

        insert #src select ''
        insert #src select '-- drop old columns'
        insert #src
        select 'alter table '+@dst_obj+' drop column '+quotename(dst)
        from #cmp_col
        where src is null

        insert #src select ''
        insert #src select '-- add new columns'
        insert #src select 'alter table '+@dst_obj+' add '+cc.col_def
        from #cmp_col cc
        where cc.dst is null

        end -- table changed

        if @noidx=0
            begin
            insert #src select ''
            insert #src select '-- add new indexes'
            insert #src
            select line
            from #src_src src
            join #cmp cmp on src.lno between cmp.src_from and cmp.src_to
            where dst_crc is null
            and xtype in ('ix','pk')

            insert #src select ''
            insert #src select '-- drop all changed or dropped indexes'
            insert #src
            select 'drop index '+quotename(@dst_obj)+'.'+quotename(cod)
            from #cmp
            where (src_crc!=dst_crc or src_crc is null)
            and xtype in ('ix')

            insert #src select ''
            insert #src select '-- re-create all changed indexes'
            insert #src
            select line
            from #src_src src
            join #cmp cmp on src.lno between cmp.src_from and cmp.src_to
            where src_crc!=dst_crc  -- nulls excluded
            and xtype in ('ix','pk')
            end

        if @notrg=0
            begin
            insert #src select ''
            insert #src select '-- drop disappeared triggers'
            insert #src
            select 'drop trigger '+quotename(cod)
            from #cmp cmp
            where (src_crc is null)
            and xtype in ('tr')

            insert #src select ''
            insert #src select '-- align triggers'
            insert #src
            select line
            from #src_src src
            join #cmp cmp on src.lno between cmp.src_from and cmp.src_to
            where (src_crc!=dst_crc or dst_crc is null)
            and xtype in ('tr')
            end -- notrg

    end -- script dst

else    -- if not exists

    begin
    truncate table #src
    insert #src select 'use ['+@dst_db+'] '
    insert #src select line from #src_src order by lno
    end

-- debug info
if @dbg>0
    begin
    select
        *,  case
            when isnull(src_crc,0)!=isnull(dst_crc,0)
            then '*'
            else ''
            end [*]
    from #cmp
    end

-- ====================================================== script print or run ==

if @dbg>0 or @run=0
    exec sp__print_table '#src'
if @run>0
    begin
    select @sql=isnull(@sql,'')+isnull(line,'')+@crlf from #src order by lno
    if @sql is null goto err_sql
    exec(@sql)
    if @@error!=0 goto err_sql
    end

-- ================================================================== dispose ==

dispose:
drop table #cmp
drop table #cmp_col
drop table #src_crc
drop table #src_src
if not object_id('tempdb..#dst_crc') is null drop table #dst_crc
drop table #src_def
drop table #src

goto ret

-- =================================================================== errors ==
err_svr:
exec @ret=sp__err 'server as source or destination is not managed',
                  @proc
goto ret

err_db:
exec @ret=sp__err 'source object must come from current db',
                  @proc
goto ret

err_obj:
exec @ret=sp__err 'cannot replicate object on itself',
                  @proc
goto ret

err_syn:
exec @ret=sp__err 'destination object exists but is not a table',
                  @proc
goto ret

err_onf:
exec @ret=sp__err 'source "%s" not found',
                  @proc,@p1=@src_obj
goto ret

err_dnf:
exec @ret=sp__err 'destination db "%s" not found',
                  @proc,@p1=@dst_db
goto ret

err_ntt:
exec @ret=sp__err 'source is not a table',
                  @proc
goto ret

err_sql:
exec sp__printsql @sql
exec @ret=sp__err 'inside sql',
                  @proc

err_scr:
goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    create a copy of table structure with different name and db;

Notes
    * create destination table if not exists
    * add index/pk if not exists on destination
    * drop destination index/pk if not exist in source
    * add/drop column if not exists or disappeared
    * comment/property are not aligned

Parameters
    @src    source table
    @dst    destination name (can contain a different db)
            can be a synonym that will be expanded
    @opt    options
            notrg   do not align triggers
            noidx   do not align indexes
            run     run script immediatelly
    @dbg    debug
            1 print code instead run it (same as not specify "run")

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__script_align