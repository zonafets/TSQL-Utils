/*  leave this
    l:see LICENSE file
    g:utility,web
    v:121018\s.zaglio: decode url
    t:select dbo.fn__web_url_decode('jeff%2Bsmith')
*/
CREATE function fn__web_url_decode(@url nvarchar(4000))
returns nvarchar(4000)
as
begin
-- from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=88926
declare @position int,
    @base char(16),
    @high tinyint,
    @low tinyint,
    @pattern char(21)

select    @base = '0123456789abcdef',
    @pattern = '%[%][0-9a-f][0-9a-f]%',
    @url = replace(@url, '+', ' '),
    @position = patindex(@pattern, @url)

while @position > 0
    select    @high = charindex(substring(@url, @position + 1, 1), @base),
        @low = charindex(substring(@url, @position + 2, 1), @base),
        @url = stuff(@url, @position, 3, char(16 * @high + @low - 17)),
        @position = patindex(@pattern, @url)

    return    @url
end -- fn__web_url_decode