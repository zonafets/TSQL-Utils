/*  leave this
    l:see LICENSE file
    g:utility
    v:151106\s.zaglio: added collate database_default
    v:111205\s.zaglio: added ?varchar(max)
    v:100710\s.zaglio: orderred by number
    v:100228\s.zaglio: a remake more simple & faster (as fn__flds_convert)
    v:091018\s.zaglio: a bug on double size of nvarchar
    v:090916\S.Zaglio: a better managemnt of temp tables
    v:090331\S.Zaglio: added manage of ## tables
    v:090202\S.Zaglio: return a series of field's types of table
    t: print dbo.fn__flds_type_of('cfg','|',null) --> name and id and xtype ...
    t:
        create table tst_fn_flds(
            i int, r real, v varchar(10), nv nvarchar(10),
            s sysname, n numeric(2,1), vcmax nvarchar(max),
            ex int)
        select * into #tst_fn_flds from tst_fn_flds
        print dbo.fn__flds_type_of('tst_fn_flds',',','ex')
        print dbo.fn__flds_type_of('#tst_fn_flds',',',null)
        drop table #tst_fn_flds drop table tst_fn_flds
*/
CREATE function [dbo].[fn__flds_type_of](@tbl sysname, @seps nvarchar(32)=',',@excludes sysname='')
returns nvarchar(4000)
as
begin
declare @cols nvarchar(4000),@db sysname,@obj sysname,@i int
declare @ex table([name] sysname)
if @seps is null select @seps=','
-- print parsename('[db..obj]',1)
-- print parsename('db..[obj]',1)
select @db=parsename(@tbl,3)
select @obj=parsename(@tbl,1)
if left(@obj,1)='#' collate database_default select @tbl='tempdb..'+@obj

if not @excludes is null
    insert @ex select token
    from dbo.fn__str_table(@excludes,@seps)

if left(@obj,1)='#' collate database_default
    select @cols
        =coalesce( @cols+ @seps, '') + t.name
        +case -- select * from systypes
         when t.xusertype in (175,239,231,167) --char,nchar,nvc,vc
            then '(' +
                    case
                    when c.prec=-1
                    then 'max'
                    else cast(c.prec as nvarchar)
                    end +
                 ')'
                                   -- (@len/case
                                   --when left(@column,1) ='n'
                                   --then 2 else 1 end) as nvarchar) + ') '
            when t.xusertype in (106,108) then '(' + cast(c.prec as nvarchar)+','+
                                                     cast(c.scale as nvarchar)+') '
         else '' end
    from tempdb..syscolumns c
    join tempdb..systypes t on c.xusertype=t.xusertype
    where c.[id]=object_id(@tbl)
    and not c.name in (select [name] collate database_default from @ex)
    order by c.number,c.colorder
else
    select @cols
        =coalesce( @cols+ @seps, '') + t.name
        +case -- select * from systypes
         when t.xusertype in (175,239,231,167) --char,nchar,nvc,vc
            then '(' +
                    case
                    when c.prec=-1
                    then 'max'
                    else cast(c.prec as nvarchar)
                    end +
                 ')'
                                   -- (@len/case
                                   --when left(@column,1) ='n'
                                   --then 2 else 1 end) as nvarchar) + ') '
            when t.xusertype in (106,108) then '(' + cast(c.prec as nvarchar)+','+
                                                     cast(c.scale as nvarchar)+') '
         else '' end
    from syscolumns c
    join systypes t on c.xusertype=t.xusertype
    where c.[id]=object_id(@tbl)
    and not c.name in (select [name] collate database_default from @ex)
    order by c.number,c.colorder

return @cols
end -- fn__flds_type_of