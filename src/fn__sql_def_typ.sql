/*  leave this
    l:see LICENSE file
    g: utility,script
    v: 100321\s.zaglio: return tsql type declaration
    t: see [fn__sql_def_col] test
*/
create function [dbo].[fn__sql_def_typ](
    @utype      int,
    @type       sysname,
    @len        int,
    @prec       int,
    @scale      int,
    @nullable   bit
)
returns nvarchar(4000)
as
begin
-- select * from systypes where xtype in (175,239,231,167)
-- select top 1 * from syscolumns
/*  select c.name,dbo.fn__sql_def_typ(c.xusertype,null,c.length,c.prec,c.scale,c.isnullable),c.*
    from syscolumns c
    where id=object_id('sp__usage')
*/
declare @def nvarchar(4000)
select @def=case when @type is null then type_name(@utype) else @type end+
            case -- select * from systypes
            when @utype in (175,239,231,167) --char,nchar,nvc,vc
            then '(' + cast(@prec as nvarchar) +') '
                                   -- (@len/case
                                   --when left(@column,1) ='n'
                                   --then 2 else 1 end) as nvarchar) + ') '
            when @utype in (106,108) then '(' + cast(@prec as nvarchar)+','+
                                                cast(@scale as nvarchar)+') '
            else ''
            end+
    -- nullable
    case when @nullable=1 then ' null ' else ' not null ' end
return @def
end -- function