/*  leave this
    l:see LICENSE file
    g:utility
    v:070701\S.Zaglio: remove left and right spaces
    t:print dbo.fn__trim(convert(nchar(20),'   hello   '))
*/
create function fn__trim(@st nvarchar(4000))
returns nvarchar(4000)
as
begin
return ltrim(rtrim(@st))
end