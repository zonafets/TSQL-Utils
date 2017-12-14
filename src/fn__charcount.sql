/*  leave this
    l:see LICENSE file
    g:utility
    v:100204\s.zaglio: count char occurrence
    todo:deprecate to fn__occurrences
    t:print dbo.fn__charcount('.','schema.table.fld')
    t:print dbo.fn__charcount('.','schema_table_fld')
    t:print dbo.fn__charcount('.',null)
*/
CREATE function [dbo].[fn__charcount](@char nchar(1),@string nvarchar(4000))
returns int
as
begin
declare @i int,@nc int
if @string is null or @char is null return null
select @i=charindex(@char,@string),@nc=0
while (@i>0)
    begin
    select @nc=@nc+1
    select @i=charindex(@char,@string,@i+1)
    end
return @nc
end -- end fn__charindex