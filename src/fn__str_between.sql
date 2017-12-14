/*  leave this
    l:see LICENSE file
    g:utility
    v:130217\s.zaglio: added option close left
    v:111205\s.zaglio: a test when left token not found
    v:111114\s.zaglio: added space as separator and correct some bug
    v:110707\s.zaglio: a bug when @str = ''
    v:100508\s.zaglio: return a pieec of string between limits
    t:print dbo.fn__str_between('a:1,b:2,c:3','a:',',',default) -->1
    t:print dbo.fn__str_between('a:1,b:2,c:3','b:',',',default) -->2
    t:print dbo.fn__str_between('a:1,b:2,c:3','c:',',',default) -->3
    t:print '|'+dbo.fn__str_between('a:1,b:2,c:3','x','y',default)+'|' -->'||'
    t:print isnull(dbo.fn__str_between(null,'c:',',',default),'???') -->???
    t:print '|'+isnull(dbo.fn__str_between('','c:',',',default),'???')+'|' -->'||'
    t:print dbo.fn__str_between('test:with space',':','',default) -->with
    t:print '|'+dbo.fn__str_between('||','|ss:','|',default)+'|' -->'||'
    t:print dbo.fn__str_between('|ss:m0|','|ss:','|',default) --> m0
    t:select dbo.fn__str_between('c:\dir\file.ext','\','.',[btw.close_right]) from enums
*/
CREATE function fn__str_between(
    @str nvarchar(4000),
    @from sysname,
    @to sysname,
    @opt smallint=null
    )
returns nvarchar(4000)
as
begin
declare @x1 int,@x2 int,@l int,@cr smallint,@lto int,@lfrom int

if @str is null or @from is null or @to is null return null
if @str='' return @str

-- spaces tric
select @lto=len('"'+@to+'"')-2,@lfrom=len('"'+@from+'"')-2

if @opt is null
    begin
    select
        @x1=case
            when @from=''
            then charindex(' ',@str)
            else charindex(@from,@str)
            end
    if @x1=0 return ''
    select
        @x1=@x1+@lfrom,
        @x2=case
            when @to=''
            then charindex(' ',@str,@x1)
            else charindex(@to,@str,@x1)
            end
    end
else
    begin
    select @cr=[btw.close_right] from enums
    if @opt=@cr
        begin
        select
            @x2=case
                when @to=''
                then dbo.fn__charindex(' ',@str,-1)
                else dbo.fn__charindex(@to,@str,-1)
                end
        if @x2=0 return ''
        select /*@x2=@x2-@lto,@x1=@x2*/ @x1=@x2-@lto
        while @x1>0 and substring(@str,@x1,@lfrom)!=@from
            select @x1=@x1-1
        if @x1>0 select @x1=@x1+@lfrom
        end
    end -- not default close_left

if @x1=@x2 return ''
select
    @l=len(@str)

if @x2=0 select @x2=@l+1
return substring(@str,@x1,@x2-@x1)
end -- fn__str_between