/*  leave this
    l:see LICENSE file
    g:utility,script
    v:110324\s.zaglio: adapted to mssql2k5
    v:100919\s.zaglio: a bug near binary size
    v:100404\s.zaglio: collate before null/not null
    v:100328\s.zaglio: bug near default
    v:100110\s.zaglio: return tsql column declaration
    t:see [fn__sql_def_tbl] test
*/
CREATE function [dbo].[fn__sql_def_col](
    @table      sysname,
    @new        sysname,
    @column     sysname,
    @utype      int,
    @type       sysname,
    @len        int,
    @prec       int,
    @scale      int,
    @nullable   bit,
    @default    sysname,
    @def_fx     sysname,
    @identity   bit,
    @computed   bit,
    @function   sysname,
    @chk        sysname,
    @chk_fx     sysname,
    @collation  sysname,
    @status     int,
    @filler     bit
)
returns nvarchar(4000)
as
begin
-- select * from systypes where xtype in (175,239,231,167)
-- select * from syscolumns c where c.type=108 id=object_id('sp__printf')
--
declare @def nvarchar(4000)
if @identity is null select @identity=case when @status & 0x80=0x80 then 1 else 0 end
if @new is null  select @new=@table
select @def=
    -- name
    @column+' '+
    -- type
    case when @computed=0
         then @type +
            case -- select * from systypes
            when @utype in (175,239,231,167) --char,nchar,nvc,vc
                 or @type in ('char','nchar','nvarchar','varchar','binary','varbinary')
            then '(' + case when @prec<0 then 'max' else cast(@prec as nvarchar) end +') '
                                   -- (@len/case
                                   --when left(@column,1) ='n'
                                   --then 2 else 1 end) as nvarchar) + ') '
            when @utype in (106,108) or @type in ('decimal','numeric')
            then '(' + cast(@prec as nvarchar)+','+
                       cast(@scale as nvarchar)+') '
         else '' end +
    -- collate
    isnull(' collate '+ @collation,'')+
    -- nullable
    case when @nullable=1 and @identity!=1 then ' null ' else ' not null ' end +
    -- identity
    case when @identity = 1
         then ' identity(' +
                cast(ident_seed(@table) as nvarchar)+','+
                cast(ident_incr(@table) as nvarchar) + ') '
         else '' end +
    -- constrain
    isnull(' constraint [' + @chk + '_' + @new+ '] check ' + @chk_fx ,'') +
    -- default
    isnull(' constraint ' + @default ,'') +
    isnull(' default ' + @def_fx ,'') +
    ''
    -- computation
    else ' as ' + @function  end

return @def
end -- fn__sql_def_col