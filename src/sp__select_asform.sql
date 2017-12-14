/*  leave this
    l:%licence%
    g:utility
    v:130517\s.zaglio: changed inner #temp tables names; added dot opt
    v:120925\s.zaglio: small bug near @where
    v:120918\s.zaglio: adding option #vars
    v:100919\s.zaglio: adde @p1,... but not well tested
    v:100214\s.zaglio: show 1st record of a table in vertical form
    t:
        select id,name,xtype,crdate
        into #t
        from sysobjects where xtype='p'
        exec sp__select_asform '#t','name="sp__select_asform"',@dbg=1
        drop table #t
*/
CREATE proc sp__select_asform
    @tbl sysname=null,
    @where nvarchar(4000)=null,
    @opt sysname=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null,
    @dbg bit=0
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0

if @tbl is null goto help

select @opt=dbo.fn__str_quote(@opt,'|'),@ret=0

declare
    @vars bit,@select bit,@sql nvarchar(max),
    @crlf nvarchar(4),@n int,
    @flds nvarchar(4000), @dot bit

select
    @tbl=parsename(@tbl,1),
    @vars=charindex('|#vars|',@opt),
    @select=charindex('|select|',@opt),
    @dot=charindex('|dot|',@opt),
    @where=replace(@where,'"',''''),
    @crlf=crlf,
    @flds=dbo.fn__flds_of(@tbl,',',null)
from fn__sym()

if not @p1 is null select @tbl=replace(@tbl,'{1}',convert(sysname,@p1,126)),
                          @where=replace(@where,'{1}',convert(sysname,@p1,126))
if not @p2 is null select @tbl=replace(@tbl,'{2}',convert(sysname,@p2,126)),
                          @where=replace(@where,'{2}',convert(sysname,@p2,126))
if not @p3 is null select @tbl=replace(@tbl,'{3}',convert(sysname,@p3,126)),
                          @where=replace(@where,'{3}',convert(sysname,@p3,126))
if not @p4 is null select @tbl=replace(@tbl,'{4}',convert(sysname,@p4,126)),
                          @where=replace(@where,'{4}',convert(sysname,@p4,126))

select @where=isnull('where '+@where,'')

create table #sp__select_asform_fld(
    id int identity primary key,
    fld sysname,
    value sql_variant null,
    dsc sysname null
    )

if @vars=1
    insert #sp__select_asform_fld(fld)
    select token as dsc
    from dbo.fn__str_table(@flds,',')
else
    insert #sp__select_asform_fld(fld,dsc)
    select token,coalesce(com.value,'') as dsc
    from dbo.fn__str_table(@flds,',')
    left join (
        select * from dbo.fn__comments(@tbl) where not column_name is null
    ) com on token=com.column_name

-- declare @tbl sysname,@where sysname select @tbl='sysobjects',@where=''

select @sql =isnull(@sql+@crlf,'')+'when '''+fld
            +''' then cast(#sp__select_asform_tmp.['+fld+'] as sql_variant)'
from #sp__select_asform_fld

select @sql ='select top 1 * into #sp__select_asform_tmp from ['+@tbl+'] '+@crlf
            +@where+@crlf
            +'update #sp__select_asform_fld set value='+@crlf
            +'case fld'+@crlf
            +@sql+@crlf
            +'end'+@crlf
            +'from #sp__select_asform_tmp'
if @dbg=1 exec sp__printsql @sql
exec(@sql)
if @@error!=0 goto err_cod

if @vars>0
    begin
    insert #vars(id,value)
    select '%'+f.fld+'%',f.value
    from #sp__select_asform_fld f left join #vars v on '%'+f.fld+'%'=v.id
    where v.id is null
    update v set v.value=f.value
    from #sp__select_asform_fld f join #vars v on '%'+f.fld+'%'=v.id
    end
else
    begin
    if @dot=1
        begin
        select @n=max(len(fld))+2 from #sp__select_asform_fld
        update #sp__select_asform_fld set
            fld=fld+replicate('.',@n-len(fld))
        end
    if @select>0
        select id,fld,value,dsc from #sp__select_asform_fld order by id
    else
        exec sp__select_astext
                'select fld,value,dsc from #sp__select_asform_fld',
                @opt=@opt
    end

drop table #sp__select_asform_fld
goto ret
-- =================================================================== errors ==
err_cod:    exec @ret=sp__err 'inside code',@proc goto ret

-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    print a vertical table with 1st record of @tbl

Parameters
    @tbl    name of table (can be a #temp)
    @where  condition to filter select
    @p1,... replaces {1},{...} into @tbl and @where
    @opt    options
            select  return results as select instead of text
            #vars   out/update table #vars with results
                    as %fld%,value
            h       passed to sp__select_astext
            noh     passed to sp__select_astext
            dot     fill fld column with dots ....
'
select @ret=-1

-- ===================================================================== exit ==
ret:
return @ret
end -- sp__select_asform