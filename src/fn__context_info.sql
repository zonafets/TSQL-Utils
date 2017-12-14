/*  leave this
    l:see LICENSE file
    g:utility
    v:120724\s.zaglio: return position of @val into context else 0
*/
CREATE function fn__context_info(@val sysname)
returns int
as
begin
declare @i int,@info varbinary(128),@code binary(2)
select @code=dbo.fn__crc16(@val)
select @info=context_info(),@i=1
while (@i<len(@info))
    begin
    if substring(@info,@i,2)=@code return @i
    select @i=@i+2
    end
return 0
end -- fn__context_info