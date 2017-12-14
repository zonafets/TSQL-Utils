/*  leave this
    l:see LICENSE file
    g:utility
    v:130922\s.zaglio: @vcresult qas nv max
    v:121018\s.zaglio: decode url
    t:select dbo.fn__web_html_decode(
*/
CREATE function fn__web_html_decode (@vcwhat nvarchar(max))
returns nvarchar(max) as
begin
declare @vcresult nvarchar(max)
declare @vccrlf varchar(2)
declare @sipos smallint,@vcencoded varchar(7),@sichar smallint

select @vccrlf=crlf from fn__sym()

select @vcresult=@vcwhat
select @sipos=patindex('%&#___;%',@vcresult)
while @sipos>0
  begin
      select @vcencoded=substring(@vcresult,@sipos,6)
      select @sichar=cast(substring(@vcencoded,3,3) as smallint)
      select @vcresult=replace(@vcresult,@vcencoded,nchar(@sichar))
      select @sipos=patindex('%&#___;%',@vcresult)
  end

select @sipos=patindex('%&#____;%',@vcresult)
while @sipos>0
  begin
      select @vcencoded=substring(@vcresult,@sipos,7)
      select @sichar=cast(substring(@vcencoded,3,4) as smallint)
      select @vcresult=replace(@vcresult,@vcencoded,nchar(@sichar))
      select @sipos=patindex('%&#____;%',@vcresult)
  end

select @vcResult=replace(@vcResult,'&quot;','"')
select @vcResult=replace(@vcResult,'&amp;','&')
select @vcResult=replace(@vcResult,'&copy;','©')
select @vcResult=replace(@vcResult,'&laquo;','«')
select @vcResult=replace(@vcResult,'&raquo;','»')
select @vcResult=replace(@vcResult,'&frac14;','¼')
select @vcResult=replace(@vcResult,'&frac12;','½')
select @vcResult=replace(@vcResult,'&iquest;','¿')

select @vcResult=replace(@vcResult,'&lt;','<')
select @vcResult=replace(@vcResult,'&gt;','>')

select @vcresult=replace(@vcresult,'<p>',@vccrlf)

return @vcresult
end -- fn__web_html_decode