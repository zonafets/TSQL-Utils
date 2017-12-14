/*  leave this
    l:see LICENSE file
    g:utility
    v:090428\S.Zaglio: provided only for study
    t:print dbo.fn__breset(6,2) -->4
*/
CREATE function fn__breset(@src int, @val int)
returns int
as
begin
return @src & (~@val)
end