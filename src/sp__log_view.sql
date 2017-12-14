/*  leave this
    l:%licence%
    g:utility
    v:131014\s.zaglio: d tag adjust
    v:121107\s.zaglio: a bug near @n of keep (now -@n)
    v:121105\s.zaglio: added KEEP option
    v:110513\s.zaglio: removed readpast
    v:110509\s.zaglio: removed out to #src because conflict !!!!
    v:110506\s.zaglio: adapted too new sp__log
    v:110505\s.zaglio: renamed into sp__log_view
    v:110504\s.zaglio: added md5 recordnize
    v:110422\s.zaglio: adapted to new log format
    v:100314\s.zaglio: search in log
    d:100314\s.zaglio: sp__log_show
    d:100314\s.zaglio: sp__log_search
    d:100314\s.zaglio: sp__trace_search
    t:
        exec sp__log '1st test',@key='sp__log_search'
        exec sp__log '1st sub test',@key='sp__log_search'
    t:sp__log_view 12
    t:sp__log_view @what=null,@ref=2
    t:sp__log_view #10
*/
CREATE proc [dbo].[sp__log_view]
    @what sql_variant=null,
    @ref sql_variant=null,
    @opt sysname=null,
    @dbg int=null
as
begin
set nocount on
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0,@dbg=isnull(@dbg,0),
    @opt=dbo.fn__str_quote(isnull(@opt,''),'|')
if @what is null and @ref is null goto help

declare
    @key varbinary(256),@txt nvarchar(4000),@rid int,
    @bt varchar(32),@bk varchar(32),@id int,@top int,
    @keep bit,@n int,@dt datetime,@tdt nvarchar(4),
    @sql nvarchar(4000),@swhat nvarchar(4000),@sref nvarchar(128)

select
    @bk=cast(sql_variant_property(@what,'BaseType') as varchar),
    @bt=cast(sql_variant_property(@ref,'BaseType') as varchar),
    @top=10000,@dt=getdate(),@swhat=cast(@what as nvarchar(4000)),
    @sref=cast(@ref as nvarchar(128))

if isnumeric(@sref)=1
    select @rid=cast(@sref as int)
else
    select top 1 @rid=id
    from [log] with (nolock)
    where [key]=@sref
    order by id desc

if @swhat like '%[dhwm]' and isnumeric(left(@swhat,len(@swhat)-1))=1
    begin
    if @rid is null goto err_ref
    select @n=left(@swhat,len(@swhat)-1),@tdt=right(@swhat,1)+right(@swhat,1)
    select @sql='select @dt=dateadd('+@tdt+',-@n,@dt)'
    exec sp_executesql @sql,N'@dt datetime out,@n int',@dt=@dt out,@n=@n
    delete from [log] where rid=@rid and dt<@dt
    select @n=@@rowcount
    if @dbg>0 exec sp__printf '-- delete %d records before %s',@n,@dt
    goto ret
    end -- keep

-- create table #src(lno int identity, line nvarchar(4000))
-- select * from #src drop table #src
-- example: sp__log_view 0x3db54b02d3fa8a637c68bea25398155e,test
if @bk in ('binary','varbinary')
    begin
    if @ref is null goto err_ref
    -- select * from log where [key]=cast('test' as sql_variant)
    -- select * from log where [key]=cast(cast('test' as sql_variant) as nvarchar(256))
    end
if @bk in ('int') select @id=cast(@what as int)
if @bk in ('nvarchar','varchar')
    begin
    select @txt=cast(@what as nvarchar(4000))
    select @key=cast(@what as varbinary(256))
    if left(@txt,1)='#' and isnumeric(substring(@txt,2,4000))=1
        select  @top=cast(substring(@txt,2,4000) as int),
                @txt=null, @key=null
    else
        select @top=1000
    if charindex('%',@txt)>0 select @key=null
    end

-- if @dbg=1 select @top,@id,@rid,@txt,@key
select top (@top)
-- select
    id, rid, dt,
    [key],
    convert(nvarchar(4000),c1) as txt,
    convert(money,c3) as n,
    convert(money,c4) as m,
    convert(int,c2) as [spid]
from [log] with (nolock)
where 1=1
and (@id is null or id=@id)
and (@rid is null or rid=@rid)
and (@key is null or [key]=@key)
and (@txt is null or cast(c1 as nvarchar(4000)) like @txt)
order by dt desc

goto ret

-- =================================================================== errors ==
err_ref:    exec @ret=sp__err 'a reference not null and correct is required'
            goto ret
-- ===================================================================== help ==
help:
exec sp__usage @proc,'
Scope
    show log info

Parameters
    @what   if numeric is the log id
            if hexadecimal is the key
            if contain % search lines like @what
            if begin with #nnn show the first nnn rows
            if end with D,H,W,M (days,hours,weeks,months)
            and @opt has "shrink", keep only lasts @what(DHWM) records
    @ref    if present become the parent of the key group
            can be the parent id
    @opt    options
            keep    delete older logs if @what like %[dhwm]

Examples
    -- show last 100 logs
    sp__log_view #100
    -- show logs of this parent key
    sp__log_view 0x9c14ce8040deb2804c7c3bc111cc10dd,test
    -- show by id
    sp__log_view 12

    sp__log_view "sys%"

    sp__log_view "15d","SP_MYPROC",@opt="keep"

'

select distinct
    case
    when substring(cast([key] as nvarchar),1,1) like '[a-zA-Z0-9]'
    then convert(nvarchar(256),[key])
    else dbo.fn__hex([key])
    end as [key]
into #keys
from [log]

exec sp__select_astext 'select * from #keys'


select @ret=-1

ret:
return @ret
end -- sp__log_view