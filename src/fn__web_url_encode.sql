/*  leave this
    l:see LICENSE file
    g:utility,web
    v:121018\s.zaglio: encode url
    t:select dbo.fn__web_url_encode('8ECEE9BE-05BD-4DD2-9D09-6C121E0924E7')
*/
CREATE function dbo.fn__web_url_encode(@strInput nvarchar(4000))
returns nvarchar(4000)
as
begin
-- from http://www.sqlteam.com/forums/topic.asp?TOPIC_ID=88926
return
replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(
replace(replace(replace(replace(replace(
replace(replace(
        @strInput,
                '%', '%25'),
            char(10), '%0A'),
            char(13), '%0D'),
                ' ', '%20'),
                ':', '%3A'),
                ';', '%3B'),
                '-', '%2D'),
                '/', '%2F'),
                '\', '%5C'),
                '!', '%21'),
                '"', '%22'),
                '#', '%23'),
                '?', '%3F'),
                '=', '%3D'),
                '@', '%40'),
                '>', '%3E'),
                '<', '%3C'),
                '$', '%24'),
                '&', '%26'),
                '[', '%5B'),
                ']', '%5D'),
                '~', '%7E'),
                '^', '%5E'),
                '`', '%60'),
                '{', '%7B'),
                '}', '%7D'),
                '|', '%7C')
end -- fn__web_url_encode