/*  leave this
    l:see LICENSE file
    g:utility
    k:binary,real,convert,c
    v:120904\s.zaglio: from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=81849
*/
create function [dbo].[fn__binaryfloat2float]
(
    @binaryfloat binary(8)
)
returns float
as
begin
    return    sign(cast(@binaryfloat as bigint))
        * (1.0 + (cast(@binaryfloat as bigint) & 0x000fffffffffffff) * power(cast(2 as float), -52))
        * power(cast(2 as float), (cast(@binaryfloat as bigint) & 0x7ff0000000000000) / 0x0010000000000000 - 1023)
end -- [fn__binaryfloat2float]