/*  leave this
    l:see LICENSE file
    g:utility
    k:table,normalize,view
    TODO:create at least clustered index
    r:120904\s.zaglio: added distinct of distinct
    r:120829\s.zaglio: normalize a table creating a dictionary
    t:sp__util_normalize 'rep05_delivery_notes',@opt='overwrite',@dbg=1
    t:exec sp__info_db 'rep05_delivery_notes%'
    t:select top 10 * from REP05_DELIVERY_NOTES_NORM
*/
CREATE proc sp__util_normalize
    @tbl sysname = null,
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
if @tbl is null and @opt='||' goto help

-- ============================================================== declaration ==
declare
    @sql nvarchar(max),                 -- final sql to execute
    @flds nvarchar(max),                -- fields list
    @from nvarchar(max),                -- from clause
    @pk nvarchar(4000),                 -- pkey cols
    @tmp nvarchar(max),
    @id int,@i int,@n int,@top int,
    @qtbl sysname,                      -- quoted table name
    @ntbl sysname,                      -- normalized name
    @dict sysname, @dict_ix sysname,    -- dictionary tbl&idx
    @qdict sysname,
    @qnorm sysname,                     -- quoted normalized table name
    @qview sysname,                     -- quoted name view
    -- options
    @overwrite bit,
    --------
    @crlf nvarchar(2),
    @end_declare bit

create table #pk(
    id int identity,
    k1 sql_variant,k2 sql_variant null,
    k3 sql_variant null, k4 sql_variant null,
    grp int null,
    )
create index #ix_pk on #pk(grp)

-- =========================================================== initialization ==
select @id=object_id(@tbl)
select @tbl=name from sys.objects where object_id=@id -- real name

select
    @ntbl=@tbl,
    @qtbl=quotename(@tbl),
    @dict=@ntbl+'_DICT',
    @dict_ix='IX_'+@ntbl+'_DICT',
    @qdict=quotename(@dict),
    @qnorm=quotename(@ntbl+'_NORM'),
    @qview=quotename(@ntbl+'_ALL'),

    -- options
    @overwrite=charindex('|overwrite|',@opt),
    --------
    @crlf=crlf,
    --------
    @end_declare=1
from fn__sym()

-- ======================================================== second params chk ==
if not exists(
    select top 1 * from sys.objects
    where object_id=@id and [type]='U'
    ) goto err_tbl

-- ===================================================================== body ==

-- collect %varchar columns
select distinct
    c.name,
    right('0000'+cast(c.column_id as sysname),4) cid,
    t.name as [type]
into #cols
-- select top 10 *
from sys.columns c
join sys.types t on c.system_type_id=t.user_type_id
where object_id=@id
-- select * from sys.types order by system_type_id

if @dbg>1 select * from #cols order by cid

-- ================================================================ get pkeys ==
select @top=dbo.fn__count(@tbl),@n=@top/65536
exec sp__printf '-- %d records in %d chunks',@i,@n
/*
select @pk=null,@i=1
select
    @pk=isnull(@pk+',','')+quotename(columnname),
    @tmp=isnull(@tmp+',','')+'K'+cast(@i as varchar),
    @i=@i+1
from fn__script_idx(@id)
where [primary]=1

select @sql='insert #pk('+@tmp+') select '+@pk+' from '+@qtbl
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)

update #pk set grp=id%65536
*/

-- goto master_tbl

-- ================================================== create dictionary table ==
-- drop view before because schemabind
if not object_id(@qview) is null exec('drop view '+@qview)

if not object_id(@dict) is null
    begin
    if @overwrite=1
        exec('drop table '+@qdict)
    else
        goto err_exs
    end

select @sql='create table '+@qdict+'(id int identity '+
            'constraint [PK'+@ntbl+'] primary key,txt nvarchar(4000))'
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)
select @sql='create /*unique*/ index ['+@dict_ix+'] on '+@qdict+'(txt)'
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)

-- for each varchar col, fill dictionary
select @sql=null
select @sql=isnull(@sql+' union'+@crlf,'')+
           +'select distinct ['+c.name+'] from '+@qtbl
           +' where not ['+c.name+'] is null'
from #cols c
where c.[type] like '%varchar'
select @sql='insert '+@qdict+@crlf+@sql+@crlf

if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)
if @@error!=0 goto err_cod

-- ======================================================== fill master table ==
master_tbl:

if not object_id(@qnorm) is null exec('drop table '+@qnorm)

-- select fld,d1.col_id as col_id,... from tbl join dict d1
select @flds=null
select @flds=isnull(@flds+','+@crlf,'')
           +case
            when c.[type] like '%varchar'
            then '    D'+cid+'.ID as ['+c.name+'_DID]'
            else '    TBL.'+c.name
            end
from #cols c
order by c.cid

select @from='from '+@qtbl+' TBL with(nolock)'+@crlf
select @from=@from
            +'left join '               -- left because can be null value
            +@qdict+' as D'+cid+' with (nolock) '
            +' on TBL.'+c.name+'=D'+cid+'.txt'+@crlf
from #cols c
where c.[type] like '%varchar'
order by c.cid

-- create
select @sql='select top 0'+@crlf+@flds+@crlf+'into '+@qnorm+@crlf+@from
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)

-- insert
select @sql ='insert '+@qnorm+@crlf
            +'select top '+cast(@top as sysname)+@crlf   -- prevent bad joins
            +@flds+@crlf+@from
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)

-- ============================================================== create view ==
create_view:

-- hints and left join prevent create of indexes on view
select @from='from dbo.'+@qnorm+' TBL '+@crlf
select @from=@from
            +'left join '               -- left because can be null value
            +'dbo.'+@qdict+' as D'+cid
            +' on TBL.'+c.name+'_DID=D'+cid+'.id'+@crlf
from #cols c
where c.[type] like '%varchar'
order by c.cid

select @flds=null
select @flds=isnull(@flds+','+@crlf,'')
           +case
            when c.[type] like '%varchar'
            then '    D'+cid+'.TXT as ['+c.name+']'
            else '    TBL.'+c.name
            end
from #cols c
-- where not c.type like '%text'    -- do not allow
-- and not c.type like '%image'     -- clustered index
order by c.cid

select @sql ='create view '+@qview+@crlf
            +'with schemabinding'+@crlf
            +'as'+@crlf
            +'select'+@crlf
            +@flds+@crlf
            +@from+@crlf
if @sql is null goto err_cod
if @dbg=1 exec sp__printsql @sql
exec(@sql)
-- ================================================================ add index ==
add_index:

goto ret

-- =================================================================== errors ==
err_tbl:
exec @ret=sp__err 'table not found or not a table',@proc goto ret
err_exs:
exec @ret=sp__err 'destination exists; use OVERWRITE option',@proc goto ret
err_cod:
exec @ret=sp__err 'inside sql code error',@proc goto ret


-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    normalize a table creating a @tbl_DICT that contain all varchars
    and a @tbl_NORM that containt linked data
    and a @tbl_ALL that is a view that join NORM with DICT.

Parameters
    @tbl    is the name of table to normalize
    @opt    options
            overwrite   overwrite dict tables if exists

Examples
    [example]
'

select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret

end -- proc sp__util_normalize