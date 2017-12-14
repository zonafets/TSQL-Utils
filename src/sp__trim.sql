/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\S.Zaglio: strim chars on left an right from strings
    s:fn__trim
    t:
        declare @st nvarchar(4000),@crlf nchar(2)
        select @crlf=char(13)+char(10),@st='
            select X
            from Y

'
        exec sp__trim @st out,@crlf
        print '/'+'*'+@st+'*'+'/'
        exec sp__trim @st out
        print '/'+'*'+@st+'*'+'/'
        select @st='hello world!'
        exec sp__trim @st out
        print '/'+'*'+@st+'*'+'/'
    exec sp__trim @st out,@crlf
    print @st
*/
CREATE proc sp__trim
    @st nvarchar(4000) out,
    @chars nvarchar(2)=' '
as
begin
declare @lchars int,@x1 int,@x2 int,@lst int,@c1 nchar(1),@c2 nchar(1)
select @c1=substring(@chars,1,1),@c2=substring(@chars,2,1)
if @c1='' and @c2 is null select @st=ltrim(rtrim(@st))
else
    begin
    select @lst=len(@st),@lchars=1,@x1=1,@x2=@lst
        while @x2>0 and substring(@st,@x2,1) in (@c1,@c2)
    select @x2=@x2-@lchars
    while @x1<@lst and substring(@st,@x1,1) in (@c1,@c2)
        select @x1=@x1+@lchars
    -- print dbo.fn__hex(convert(varbinary(4000),@st))
    -- exec sp__printf 'x1=%d,x2=%d',@x1,@x2
    select @st=substring(@st,@x1,@x2-@x1+1)
    end
end -- proc