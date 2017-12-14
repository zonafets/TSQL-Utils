/*  leave this
    l:see LICENSE file
    g:utility
    v:100724\s.zaglio: added = and '
    v:100228\s.zaglio: remove non ascii chars
    t:print dbo.fn__str_print('abc:.d{f|5}6~4&-ò§sd=''')
*/
CREATE function [dbo].[fn__str_print] (@s nvarchar(4000))
returns nvarchar(4000)
as
begin
/*
declare @i int select @i=32
while @i<128  begin
    print convert(sysname,@i)+' '+char(@i)
    select @i=@i+1
    end
*/
declare @i int,@p sysname
select @s=convert(varchar(4000),@s)
select @p='%[^''=a-zA-Z0-9!-~ -]%'
-- select @p='%[^!-~ ]%'
select @i = patindex(@p, @s)
while @i > 0
begin
    select @s = replace(@s, substring(@s, @i, 1), ' ')
    select @i = patindex(@p, @s)
end
return @s
end -- fn__str_print