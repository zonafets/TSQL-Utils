/*  leave this
    l:%licence%
    g:utility
    d:130630\s.zaglio: sp__maint_stats
    v:130707\s.zaglio: added multi pattern
    v:130630\s.zaglio: added rwstat option
    v:120910\s.zaglio: added density option
    v:120831\s.zaglio: added norm option
    v:120116\s.zaglio: added curr_idnt
    v:111216\s.zaglio: added index size in order
    v:100919.1005\s.zaglio: a remake
    t:
        select top 10 * into test from sysobjects
        exec sp__info_db 'test'
        -- exec sp_spaceused 'ORDRSP_EDK14'
        drop table test
    t:sp__info_db #,@dbg=1,@opt='norm'
    t:sp__info_db 'cf%|ts%'
*/
CREATE proc [dbo].[sp__info_db]
    @objs nvarchar(512) = null,
    @opt  sysname = null,
    @dbg bit=0
as
begin
set nocount on

declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

-- declarations
declare
    @svr sysname,@db sysname,@sch sysname,@obj sysname,
    @qobj sysname,@id int,
    @sql nvarchar(max),@noout bit,@i int,@n int,
    @crlf varchar,
    @nodrop bit, @tbl_def nvarchar(4000)

select
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|'),
    @noout=1,@nodrop=0,
    @crlf=crlf
from fn__sym()

if @objs is null goto help

if @objs='#' select @objs='%'

select @svr=svr,@db=db,@sch=sch,@obj=obj
-- select *
from dbo.fn__parsename(@objs,0,1)

if @svr!=dbo.fn__servername(null) goto err_lso

create table #likes(pattern sysname)
insert #likes select token from fn__str_table(@objs,'|')

if object_id('tempdb..#objs') is null
    create table #objs(id int identity,obj sysname)
else
    select @nodrop=1

if object_id('tempdb..#info_db') is null
    begin
    create table #info_db (
        id int identity,

        [name] sysname,
        [rows] int          null,
        reserved sysname    null,
        data sysname        null,
        index_size sysname  null,
        unused sysname      null,

        max_row_len int     null,
        data_n int          null,
        index_size_n int    null,
        unused_n int        null,
        avg_bXrec real      null,
        ncols smallint      null,   -- number of columns
        curr_idnt bigint    null,   -- last/max identity value
        norm bigint         null,   -- size of normalized data

        useeks bigint       null,   -- whole index user seeks
        uscans bigint       null,   -- whole index user scans
        ulckps bigint       null,   -- whole index user lookups
    )
    end
else
    select @noout=0

set @sql='
    use [%db%]
    insert into #objs(obj)
    select o.name
    from sysobjects o
    join #likes l on o.name like l.pattern
    where xtype=''u''
    '
exec sp__str_replace @sql out,'%db%|%obj%',@db,@obj

exec(@sql)

drop table #likes

select @i=min(id),@n=max(id) from #objs
while (@i<=@n)
    begin
    select @obj=quotename(@db)+'.'+quotename(@sch)+'.'+quotename(obj)
    from #objs where id=@i

    insert #info_db([name],[rows],reserved,data,index_size,unused)
    exec sp_spaceused @obj

    select @i=@i+1
    end -- while

if @dbg=1
    select
        [name],
        data,
        convert(int,dbo.fn__str_at(data,'',1)) data_n,
        dbo.fn__str_at(data,'',2) data_t,
        index_size,
        convert(int,dbo.fn__str_at(index_size,'',1)) index_size_n,
        dbo.fn__str_at(data,'',2) index_size  ,
        unused,
        convert(int,dbo.fn__str_at(unused,'',1)) unused_n,
        dbo.fn__str_at(unused,'',2) unused
    from #info_db
    order by [name]

update #info_db set
    data_n      =convert(int,dbo.fn__str_at(data,'',1)),
    data        =dbo.fn__str_at(data,'',2),
    index_size_n=convert(int,dbo.fn__str_at(index_size,'',1)),
    index_size  =dbo.fn__str_at(data,'',2),
    unused_n    =convert(int,dbo.fn__str_at(unused,'',1)),
    unused      =dbo.fn__str_at(unused,'',2),
    curr_idnt   =ident_current([name])

update #info_db set
    avg_bXrec   =
        (1.0*data_n*case data when 'kb' then 1024 when 'mb' then 1024*1024 else -1 end+
         1.0*index_size_n*case index_size when 'kb' then 1024 when 'mb' then 1024*1024 else -1 end-
         1.0*unused_n*case unused when 'kb' then 1024 when 'mb' then 1024*1024 else -1 end
        ) / [rows]
where [rows]>0

declare cs cursor local for
    select [name],object_id(name),quotename(name)
    from #info_db
open cs
while 1=1
    begin
    fetch next from cs into @obj,@id,@qobj
    if @@fetch_status!=0 break

    select @sql='
        update #info_db set
        ncols=( select count(*)
                from '+quotename(@db)+'..syscolumns with (nolock)
                where id='+convert(sysname,object_id(@obj))+')
        where [name]='''+@obj+'''
        '
    exec(@sql)

    if charindex('|norm|',@opt)>0
        begin
        if @dbg>0 exec sp__printf '-- collecting norm.info for %s',@obj
        select @sql=null
        -- convert all in sql_variant to allow union
        select @sql = isnull(@sql+'union'+@crlf,'')
                    + 'select cast('+quotename(c.name)+' as sql_Variant) a '
                    + 'from '+@qobj+' with (nolock) '
                    + 'where not '+quotename(c.name)+' is null'
                    + @crlf
        from sys.columns c
        join sys.types t on c.user_type_id=t.user_type_id
        where object_id=@id
        -- select * from sys.types
        and not t.name in ( 'image','text','ntext','xml',
                            'varbinary','binary',
                            'varchar','nvarchar',
                            'char','nchar'
                           )
        and not t.max_length<8
        -- sum lens (+8 meand id and ref id)
        select @sql = 'select '
                    + '@n=sum(datalength(a)+8)/1024 '
                    + 'from ('+@crlf+@sql+') tbl'+@crlf
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end

        -- add blob & binary data
        select @sql = @sql
                    + 'select '
                    + '@n=@n+sum(datalength('+quotename(c.name)+')+8) '
                    + 'from '+@qobj+@crlf
                    + 'where not '+quotename(c.name)+' is null'
                    + @crlf
        from sys.columns c
        join sys.types t on c.user_type_id=t.user_type_id
        where object_id=@id
        and t.name in ('image','text','ntext','xml','varbinary','binary')
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end

        -- varchar(max) cannot converted as variant but simply distuinguisced
        select @sql=null
        select @sql = isnull(@sql+'union'+@crlf,'')
                    + 'select cast('+quotename(c.name)+' as nvarchar(max)) a '
                    + 'from '+@qobj+' with (nolock) '
                    + 'where not '+quotename(c.name)+' is null'
                    + @crlf
        from sys.columns c
        join sys.types t on c.user_type_id=t.user_type_id
        where object_id=@id
        and t.name in ( 'varchar','nvarchar','char','nchar' )
        -- sum lens
        select @sql = 'select '
                    + '@n=@n+sum(datalength(a)+8)/1024 '
                    + 'from ('+@crlf+@sql+') tbl'+@crlf
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end

        -- max_datalen<8 for data non normalizable
        select @sql=null
        select @sql = isnull(@sql+@crlf,'')
                    + 'select @n=@n+sum(datalength('+quotename(c.name)+'))/1024 '
                    + 'from '+@qobj+' with (nolock) '
                    + 'where not '+quotename(c.name)+' is null'
                    + @crlf
        from sys.columns c
        join sys.types t on c.user_type_id=t.user_type_id
        where object_id=@id
        and t.max_length<8
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end

        -- finally update tbl info
        exec('update #info_db set norm=@n where name='''+@obj+'''')

        end -- norm

    if charindex('|density|',@opt)>0
        begin
        -- sp__info_db #,@dbg=1,@opt='density'
        if @dbg>0 exec sp__printf '-- collecting density info for %s',@obj
        select @sql=null
        -- convert all in sql_variant to allow union
        select @sql = isnull(@sql+'+'+@crlf,'')
                    + '(select count(*) '
                    + 'from '+@qobj+' with (nolock) '
                    + 'where '+quotename(c.name)+' is null)'
                    + @crlf
        -- select top 10 *
        from sys.columns c
        join sys.types t on c.user_type_id=t.user_type_id
        where object_id=@id and c.is_computed=0
        select @sql='select @n='+@crlf+@sql
        select @n=0
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end
        if @n>0
            begin
            select @sql='update #info_db set '+
                 'norm=100-((1.0*@n/(1.0*rows*ncols))*100.0) '+
                 'where name='''+@obj+''''
            exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
            if @ret!=0
                begin
                exec sp__printsql @sql
                goto err_cod
                end
            end -- n>0
        end -- density

    if charindex('|rwstat|',@opt)>0
        begin
        -- sp__info_db '#',@opt='rwstat'
        select @sql='
            update nfo set useeks=user_seeks,uscans=user_scans,ulckps=user_lookups
            from #info_db nfo
            join (
                select object_name(ustat.object_id) as name,
                    /*
                    proportion_of_reads=case
                        when sum(user_updates + user_seeks + user_scans + user_lookups) = 0 then null
                        else cast(sum(user_seeks + user_scans + user_lookups) as decimal)
                                    / cast(sum(user_updates
                                                + user_seeks
                                                + user_scans
                                                + user_lookups) as decimal(19,2))
                        end,
                    proportion_of_writes=case
                        when sum(user_updates + user_seeks + user_scans + user_lookups) = 0 then null
                        else cast(sum(user_updates) as decimal)
                                / cast(sum(user_updates
                                            + user_seeks
                                            + user_scans
                                            + user_lookups) as decimal(19,2))
                        end,
                    sum(user_seeks + user_scans + user_lookups) as total_reads
                    sum(user_updates) as total_writes
                    */
                    sum(user_seeks) as user_seeks,
                    sum(user_scans) as user_scans,
                    sum(user_lookups) as user_lookups
                from sys.dm_db_index_usage_stats as ustat
                join sys.indexes as i
                    on ustat.object_id = i.object_id
                        and ustat.index_id = i.index_id
                join sys.tables as t
                    on t.object_id = ustat.object_id
                where i.type_desc in ( ''clustered'', ''heap'' )
                group by ustat.object_id
                ) as idxs
                on nfo.name=idxs.name
                '
        exec @ret=sp_executesql @sql,N'@n int out',@n=@n out
        if @ret!=0
            begin
            exec sp__printsql @sql
            goto err_cod
            end
        end -- rwstat

    end -- while of cursor
close cs
deallocate cs

if @noout=1
    begin
    select *
    from #info_db
    order by (data_n-unused_n+index_size_n) desc
    drop table #info_db
    end

if @nodrop=0 drop table #objs

goto ret

-- =================================================================== errors ==

err_lso:    exec @ret=sp__err 'local server only',@proc goto ret
err_cod:    exec @ret=sp__err 'inside sql code',@proc goto ret

-- ===================================================================== help ==

help:
exec sp__usage @proc,'
Scope
    list info about space used by table objects

Parameters
    @objs       db, schema and object name to inspect
                obj can use wildchar like % and _
                multiple group of objects can be separated by | (pipe)
                if @objs is #, means all tables of current db
    @opt        options
                norm    fill norm row with estime of normalized data(very slow)
                        (work only on objects of local db)
                density fill norm row with % of rapport between not null values
                        and n. of rows
                rwstat  fill useeks, uscans, ulckps

    #info_db    fill this table instead show results.
                create table #info_db (
                    id int identity,

                    [name] sysname,
                    [rows] int          null,
                    reserved sysname    null,
                    data sysname        null,
                    index_size sysname  null,
                    unused sysname      null,

                    max_row_len int     null,
                    data_n int          null,
                    index_size_n int    null,
                    unused_n int        null,
                    avg_bXrec real      null,
                    ncols smallint      null,   -- number of columns
                    curr_idnt bigint    null,   -- last/max identity value
                    norm bigint         null,   -- size of normalized data or density

                    useeks bigint       null,   -- whole index user seeks
                    uscans bigint       null,   -- whole index user scans
                    ulckps bigint       null    -- whole index user lookups
                )

Notes
    If table #info_db is passed, data is returned and not shown
    Can be passed #objs to sub select tables
        create table #objs(id int identity,obj sysname)

Examples
    exec sp__info_db ''te%''

',@p1=@tbl_def
select @ret=-1
ret:
return @ret
end -- sp__info_db