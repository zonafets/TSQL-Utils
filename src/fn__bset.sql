/*  leave this
    l:see LICENSE file
    g:utility
    v:090428\S.Zaglio: provided only for study
    t:print dbo.fn__bset(4,2) -->6
*/
CREATE function fn__bset(@src int, @val int)
returns int
as
begin
return @src | @val
end