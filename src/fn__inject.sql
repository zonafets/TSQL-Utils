/*  leave this
    l:see LICENSE file
    g:utility
    v:080414\S.Zaglio:inculate a string or sql
*/
CREATE   function [dbo].[fn__inject](
    @sql nvarchar(4000)
)
returns nvarchar(4000)
AS
begin
set @sql=replace(@sql,'''','''''')
return @sql
end