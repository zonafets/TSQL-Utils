/*  leave this
    l:see LICENSE file
    g:utility
    c:http://classicasp.aspfaq.com/general/what-is-wrong-with-isnumeric.html
    c:http://codecorner.galanter.net/2009/04/03/tsql-isnumeric-function-returns-false-positives/
    v:130729\s.zaglio:new concept
    v:120305\s.zaglio:bug near hexadecimal
    v:120213\s.zaglio:added hexadecimal
    v:110627\s.zaglio:extend mssql isnumeric
    t:print dbo.fn__isnumeric('test test') -- 0
    t:print dbo.fn__isnumeric(0x80035C56) -- 0
    t:print dbo.fn__isnumeric('0xfffe') -- 1
    t:print dbo.fn__isnumeric('0xfffx') -- 0
    t:print dbo.fn__isnumeric('0xfx00') -- 0
    t:print dbo.fn__isnumeric('0.123')  -- 1
    t:select isnumeric('0.123.23'),dbo.fn__isnumeric('0.123.23') print convert(float,'0.123.23')
    t:print isnumeric('0,123')    print convert(float,'0,123') -- error
    t:print dbo.fn__isnumeric('0,123,23') -- 0
    todo:manage numbers with ,,,...
*/
CREATE function fn__isnumeric(@vs nvarchar(4000))
returns bit
as
begin
declare @i int,@n int
if left(@vs,2)='0x'
    if substring(@vs,3,4000) like '%[^0-9abcdef]%' return 0
    else return 1

if charindex('e', @vs)!=0 return isnumeric(@vs)
else return isnumeric(@vs+'e0')

return null
end -- fn__isnumeric