/*  leave this
    l:see LICENSE file
    g:utility
    v:110601\s.zaglio: added columns def
    v:100404\s.zaglio: list simples create table columns
    t:
        create table test_cols(
            a int, b sysname,c bit,d numeric(4,2),
            e varchar(3),f nvarchar(2),
            u uniqueidentifier
            )
        select * into #test from test_cols
        select * from fn__sql_def_cols('test_cols',default,default)
        select * from fn__sql_def_cols('test_cols',default,'b,d')
        select * from fn__sql_def_cols('#test',default,default)
        drop table #test
        drop table test_cols
    t:select * from systypes order by [type]
*/
CREATE function [dbo].[fn__sql_def_cols](
    @tbl sysname,
    @sep nvarchar(32)=',',
    @excludes nvarchar(4000)=null
    )
returns @cols table (
    fld sysname,def sysname,ord int,sep nchar(1),
    [type] sysname,[prec] nvarchar(32),[scale] nvarchar(32),
    gtype nvarchar(2)   -- N=numeric, S=string, B=binary, V=variant
    )
as
begin
declare @ex table (fld sysname)
if not @excludes is null
    insert @ex
    select token
    from dbo.fn__str_table(@excludes,@sep)

if left(@tbl,1)!='#'
    insert @cols(fld,def,ord,sep,[type],[prec],scale,gtype)
    select
        c.name fld,
        dbo.fn__sql_def_typ(t.xusertype,t.name,c.length,c.prec,c.scale,c.isnullable) def,
        c.colorder,
        @sep,
        t.name,
        case when c.xtype=c.xusertype then cast(c.prec as sysname)  else null end,
        c.scale,
        case when t.xtype in (35,99,167,231,175,239) then 'S'
             when t.xtype in (34,165,36,173) then 'B'
             when t.xtype in (98) then 'V'
             else 'N'
        end
    from syscolumns c join systypes t on t.xusertype=c.xusertype
    where c.id=object_id(@tbl)
    and not c.name in (select fld from @ex)
else
    insert @cols(fld,def,ord,sep,[type],prec,scale,gtype)
    select
        c.name fld,
        dbo.fn__sql_def_typ(t.xusertype,t.name,c.length,c.prec,c.scale,c.isnullable) def,
        c.colorder,
        @sep,
        t.name,
        case when c.xtype=c.xusertype then cast(c.prec as sysname) else null end,
        c.scale,
        case when t.xtype in (35,99,167,231,175,239) then 'S'
             when t.xtype in (34,165,36,173) then 'B'
             when t.xtype in (98) then 'V'
             else 'N'
        end
    from tempdb..syscolumns c join systypes t on t.xusertype=c.xusertype
    where c.id=object_id('tempdb..'+@tbl)
    and not c.name in (select fld from @ex)

update @cols set sep='' where ord=(select max(ord) from @cols)
return
end -- fn__sql_def_cols