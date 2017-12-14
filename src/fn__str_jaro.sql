/*  leave this
    l:see LICENSE file
    g:utility
    r:100125\s.zaglio: alternative to fn__str_distance based on jaro algho
    c:originally from http://www.sqlservercentral.com/articles/Fuzzy+Match/65702/
    t:print dbo.fn__str_jaro('Peter','Pete')    -- 0.933332
    t:print dbo.fn__str_jaro('Peter','Peter')
*/
CREATE function [dbo].[fn__str_jaro](@str1 varchar(4000), @str2 varchar(4000))
returns float as
begin
declare @jaro_distance float
declare @jaro_winkler_distance float
declare @prefixlength int
declare @prefixscalefactor float

-- used by calc of prefixlength
declare @i int
declare @n int
declare @foundit bit

-- used by calc of jaro
declare @common1 varchar(4000)
declare @common2 varchar(4000)
declare @common1_len int
declare @common2_len int
declare @s1_len int
declare @s2_len int
declare @match_window int
set @jaro_distance = 0

-- used by calc transposition
declare @transpose_cnt int
set @transpose_cnt = 0

set @prefixscalefactor = 0.1 --constant = .1

if @str1 is not null and @str2 is not null
    begin

    -- set @jaro_distance = dbo.fn__str_jaro_calc(@str1, @str2)
    set @match_window = 0
    set @s1_len = len(@str1)
    set @s2_len = len(@str2)
    -- set @match_window = dbo.fn__str_jaro_clmw(@s1_len, @s2_len)     -- calclatematchwindow
    set @match_window = case
        when @s1_len >= @s2_len
        then (@s1_len / 2) - 1
        else (@s2_len / 2) - 1
        end -- case

    set @common1 = dbo.fn__str_jaro_gcc(@str1, @str2, @match_window,@s1_len,@s2_len) -- getcommoncharacters
    set @common1_len = len(@common1)
    if @common1_len = 0 or @common1 is null goto exit_dist
    set @common2 = dbo.fn__str_jaro_gcc(@str2, @str1, @match_window,@s1_len,@s2_len)
    set @common2_len = len(@common2)
    if @common1_len <> @common2_len or @common2 is null goto exit_dist

    -- begin calc transposition
    -- set @transpose_cnt = dbo.fn__str_jaro_ctp](@common1_len, @common1, @common2) -- calctranspositions
    set @i = 0
    while @i < @s1_len
        begin
        if substring(@str1, @i+1, 1) <> substring(@str2, @i+1, 1)
            set @transpose_cnt = @transpose_cnt + 1
        set @i = @i + 1
        end -- while

    set @transpose_cnt  = @transpose_cnt / 2

    -- end calc transposition

    set @jaro_distance = @common1_len / (3.0 * @s1_len) + @common1_len / (3.0 * @s2_len) +
                        (@common1_len - @transpose_cnt) / (3.0 * @common1_len);

    exit_dist:


    -- set @prefixlength = dbo.fn__str_jaro_calc_pl(@str1, @str2)
    set @i = 0
    set @foundit = 0
    set @n = case
        when @prefixlength < @s1_len and @prefixlength < @s2_len
        then @prefixlength
        when @s1_len < @s2_len and @s1_len < @prefixlength
        then @s1_len
        else @s2_len
        end -- case
    while @i < @n and @foundit = 0
        begin
        if substring(@str1, @i+1, 1) <> substring(@str2, @i+1, 1)
            begin
            set @prefixlength = @i
            set @foundit = 1
            end
        set @i = @i + 1
        end -- while
    end -- if not str nulls
else
    set @prefixlength = 4

set @jaro_winkler_distance = @jaro_distance + ((@prefixlength * @prefixscalefactor) * (1.0 - @jaro_distance))
return @jaro_winkler_distance
end -- function