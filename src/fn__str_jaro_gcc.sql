/*  leave this
    l:see LICENSE file
    g:utility
    v:100125\s.zaglio: used by fn__str_jaro_gcc
    c:originally from www.sqlservercentral.com
    t:print dbo.fn__str_jaro('Peter','Pete')
*/
create function [dbo].fn__str_jaro_gcc(
    @str1 varchar(4000),
    @str2 varchar(4000),
    @match_window int,
    @s1_len int,
    @s2_len int
)
returns varchar(4000) as
begin
declare @commonchars varchar(4000)
declare @copy varchar(4000)
declare @char char(1)
declare @foundit bit

declare @i int
declare @j int
declare @j_max int

set @commonchars = ''
set @copy = @str2

set @i = 1
while @i < (@s1_len + 1)
    begin
    set @char = substring(@str1, @i, 1)
    set @foundit = 0

    -- set j starting value
    if @i - @match_window > 1
        set @j = @i - @match_window
    else
        set @j = 1 -- set j stopping value

    if @i + @match_window <= @s2_len
        set @j_max = @i + @match_window
    else
        if @s2_len < @i + @match_window set @j_max = @s2_len

    while @j < (@j_max + 1) and @foundit = 0
        begin
        if substring(@copy, @j, 1) = @char
            begin
            set @foundit = 1
            set @commonchars = @commonchars + @char
            set @copy = stuff(@copy, @j, 1, '#')
            end
        set @j = @j + 1
        end -- while @j<...
    set @i = @i + 1
    end -- while @i<...

return @commonchars
end -- function