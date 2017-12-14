/*  leave this
    l:see LICENSE file
    g:utility
    v:090624\s.zaglio: default left/right trim
    v:081016\S.Zaglio: remove initila crlf and spaces
    v:080814\S.Zaglio: added replace of CRLF+SPACE to CRLF and corrected a bug nchar(13)->char(10)
    v:080812\S.Zaglio: added replace of SPACE+CRLF to CRLF
    v:080717\S.Zaglio: added @trim  (1=left,2=left,0=left&right)
    v:080401\S.Zaglio: remove double spaces, crlf, tabs
    t:print '|'+dbo.fn__str_simplify('  test  2space   3space   ',default)+'|'
    t:print '|'+dbo.fn__str_simplify('  test  2space   3space   ',1)+'|'
*/
CREATE function fn__str_simplify(@str nvarchar(4000),@trim smallint=0)
returns nvarchar(4000)
as
begin
declare @crlf nchar(2)
set @crlf=char(13)+char(10)
if @trim=1 set @str=ltrim(@str)
if @trim=2 set @str=rtrim(@str)
if @trim=0 set @str=ltrim(rtrim(@str))
while left(@str,2)=@crlf set @str=substring(@str,3,len(@str))
while isnull(charindex(nchar(9),        @str),0)>0 set @str=replace(@str,char(9),        ' ')
while isnull(charindex(@crlf+@crlf,    @str),0)>0 set @str=replace(@str,@crlf+@crlf,    @crlf)
while isnull(charindex('   ',          @str),0)>0 set @str=replace(@str,'   ',          ' ')
while isnull(charindex('  ',           @str),0)>0 set @str=replace(@str,'  ',           ' ')
while isnull(charindex(' '+@crlf,      @str),0)>0 set @str=replace(@str,' '+@crlf,      @crlf)
while isnull(charindex(@crlf+' ',      @str),0)>0 set @str=replace(@str,@crlf+' ',      @crlf)
while isnull(charindex(' '+@crlf+' ',  @str),0)>0 set @str=replace(@str,' '+@crlf+' ',  @crlf)
return @str
end -- fn__str_simplify