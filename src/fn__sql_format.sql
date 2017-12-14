/*  leave this
    l:see LICENSE file
    g:utility
    v:091022\s.zaglio: better view
    v:080815\S.Zaglio: reformat a string that containt sql code
    t:
        begin
        declare @s nvarchar(500)
        set @s='select     a,      b,       c,      from '+char(13)+char(10)+'      table'
        set @s=dbo.fn__sql_format(@s,120)
        print @s
        end
*/
CREATE function [dbo].[fn__sql_format](@sql nvarchar(4000), @wrap smallint)
returns nvarchar(4000)
as
begin
declare @crlf nchar(2) select @crlf=char(13)+char(10)
set @sql=replace(lower(@sql),@crlf,' ')
set @sql=replace(@sql,'update ',    @crlf+'UPDATE ')
set @sql=replace(@sql,'insert ',    @crlf+'INSERT ')
set @sql=replace(@sql,'select ',    @crlf+'SELECT ')
set @sql=replace(@sql,'set ',       'SET ')
set @sql=replace(@sql,'right ',     'RIGHT ')
set @sql=replace(@sql,'INNER ',     'INNER ')
set @sql=replace(@sql,'outer ',     'OUTER ')
set @sql=replace(@sql,'join ',      'JOIN ')
set @sql=replace(@sql,'on ',        'ON ')
set @sql=replace(@sql,'or ',        'OR ')
set @sql=replace(@sql,'and ',       'AND ')
set @sql=replace(@sql,'set ',       'SET ')
set @sql=replace(@sql,'left ',      'LEFT ')
set @sql=replace(@sql,'from ',      @crlf+'FROM ')
set @sql=replace(@sql,'into ',      'INTO ')
set @sql=replace(@sql,'where ',     @crlf+'WHERE ')
set @sql=replace(@sql,'order by ',  @crlf+'ORDER BY ')
set @sql=replace(@sql,'group by ',  'GROUP BY ')
return dbo.fn__str_split(dbo.fn__str_simplify(@sql,0),@wrap)
end