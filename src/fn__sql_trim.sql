/*  leave this
    l:see LICENSE file
    g:utility
    v:120412\s.zaglio: left and right trim lines to allow correct indent into code
    t:
        print dbo.fn__sql_trim('
            /* test
                v:120412\s.zaglio:test
            */
            create proc
            -- test 2 right spaces
            ')
*/
CREATE function fn__sql_trim(@sql nvarchar(max))
returns nvarchar(max)
as
begin
declare @tmp nvarchar(max),@crlf nvarchar(2),@i int,@j int,@p int
declare @src table(lno int identity primary key,line nvarchar(4000))

select @crlf=crlf from fn__sym()

insert @src(line) select token
from dbo.fn__str_table(@sql,@crlf)

select top 1 @i=lno from @src where ltrim(rtrim(line))!='' order by lno
select top 1 @j=lno from @src where ltrim(rtrim(line))!='' order by lno desc

select @p=patindex('%[^ ]%',line) from @src where lno=@i

select @tmp=''
select @tmp=@tmp+rtrim(substring(line,@p,4000))+@crlf
from @src
where lno between @i and @j

return @tmp
end -- fn__sql_trim