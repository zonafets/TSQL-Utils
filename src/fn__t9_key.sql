/*  leave this
    l:see LICENSE file
    g:utility
    v:090430\S.Zaglio: revision: added @max_len and set result to bigint
*/
CREATE function [dbo].[fn__t9_key](@string nvarchar(4000),@max_len tinyint=9)
returns bigint
as
begin
declare @c nvarchar(1)
declare @i int set @i=1
declare @r bigint set @r=0
if @max_len>19 set @max_len=19
while (@i<=@max_len and @i<=len(@string)) begin
    set @r=@r*10
    set @c=substring(@string,@i,1)
    set @i=@i+1
    if @c='0' and @i=1 begin set @r=-@r continue end
    if @c='1' begin set @r=@r+1 continue end
    if @c like '[2abc]' begin set @r=@r+2 continue end
    if @c like '[3def]' begin set @r=@r+3 continue end
    if @c like '[4ghi]' begin set @r=@r+4 continue end
    if @c like '[5jkl]' begin set @r=@r+5 continue end
    if @c like '[6mno]' begin set @r=@r+6 continue end
    if @c like '[7pqrs]' begin set @r=@r+7 continue end
    if @c like '[8tuv]'  begin set @r=@r+8 continue end
    if @c like '[9wxyz]' begin set @r=@r+9 continue end
end -- while
return @r
end -- function