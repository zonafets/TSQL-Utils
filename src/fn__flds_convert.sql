/*  leave this
    l:see LICENSE file
    g:utility
    v:131014\s.zaglio: d tag adjust
    v:100228\s.zaglio: standard types convertion for tables
    d:100228\s.zaglio: fn__flds_row
    t:
        create table test_convert(a int,b float,c datetime,t sysname)
        select * into #test_convert  from test_convert
        select * into ##test_convert from test_convert
        print 'table:'+dbo.fn__flds_convert('test_convert',null,'t')
        print '#table:'+dbo.fn__flds_convert('#test_convert',null,null)
        print '##table:'+dbo.fn__flds_convert('##test_convert',null,null)
        print isnull(dbo.fn__flds_convert(null,null,null),'???')
        drop table test_convert
        drop table #test_convert
        drop table ##test_convert
*/
CREATE function [dbo].[fn__flds_convert](
    @tbl sysname,
    @seps nvarchar(32)=',',
    @excludes sysname=''
)
returns nvarchar(4000)
as
begin
declare @convs nvarchar(4000),@db sysname,@obj sysname,@i int
declare @ex table([name] sysname)
if @seps is null select @seps=','
-- print parsename('[db..obj]',1)
-- print parsename('db..[obj]',1)
select @db=parsename(@tbl,3)
select @obj=parsename(@tbl,1)
if left(@obj,1)='#' select @tbl='tempdb..'+@obj

if not @excludes is null
    insert @ex select token
    from dbo.fn__str_table(@excludes,@seps)

if left(@obj,1)='#'
    select
            @convs=coalesce( @convs + @seps, '') +
                case when t.name in ('datetime', 'smalldatetime')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',126) as ' + quotename(c.name)
                     when t.name in ('numeric', 'decimal')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',128) as ' + quotename(c.name)
                     when t.name in ('float', 'real', 'money', 'smallmoney')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',2) as ' + quotename(c.name)
                     when t.name in ('datetime', 'smalldatetime')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',120) as ' + quotename(c.name)
                     when t.name in ('image','text','ntext')
                     then 'dbo.fn__hex(textptr('+quotename(c.name)+')) as ' + quotename(c.name)
                     else quotename(c.name)
                end
    from tempdb..syscolumns c
    join tempdb..systypes t on c.xusertype=t.xusertype
    where c.[id]=object_id(@tbl)
    and not c.name in (select [name] from @ex)
    order by colorder
else
    select
            @convs=coalesce( @convs + @seps, '')+
                case when t.name in ('datetime', 'smalldatetime')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',126) as ' + quotename(c.name)
                     when t.name in ('numeric', 'decimal')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',128) as ' + quotename(c.name)
                     when t.name in ('float', 'real', 'money', 'smallmoney')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',2) as ' + quotename(c.name)
                     when t.name in ('datetime', 'smalldatetime')
                     then 'convert(nvarchar(4000),'+quotename(c.name)+',120) as ' + quotename(c.name)
                     when t.name in ('image','text','ntext')
                     then 'dbo.fn__hex(textptr('+quotename(c.name)+')) as ' + quotename(c.name)
                     else quotename(c.name)
                end
    from syscolumns c
    join systypes t on c.xusertype=t.xusertype
    where c.[id]=object_id(@obj)
    and not c.name in (select [name] from @ex)
    order by colorder

return @convs
end -- fn__flds_convert