/*  leave this
    l:see LICENSE file
    g:utility
    k:binary,real,convert,c
    v:120904\s.zaglio: from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=81849
*/
create function [dbo].[fn__binaryreal2real]
(
    @binaryfloat binary(4)
)
returns real
as
begin
    return    sign(cast(@binaryfloat as int))
        * (1.0 + (cast(@binaryfloat as int) &  0x007fffff) * power(cast(2 as real), -23))
        * power(cast(2 as real), (cast(@binaryfloat as int) & 0x7f800000) / 0x00800000 - 127)
end -- fn__binaryreal2real