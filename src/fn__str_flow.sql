/*  leave this
    l:see LICENSE file
    g:utility
    k:text,layout,grid
    v:120810.1200\s.zaglio: flow a horiz. list of items into a grid
    t:
        print dbo.fn__str_flow('abcdefghi,abcdefghi,abcdefghi,abcdefghi,'+
                               'abcdefghi,abcdefghi,abcdefghi,abcdefghi',
                               ',',
                               default)
*/
CREATE function fn__str_flow(
    @list nvarchar(4000),
    @sep nvarchar(32),
    @opt sysname = null
    )
returns nvarchar(4000)
as
begin
declare
    @n int,@ret nvarchar(4000),@width smallint,@ll int,
    @crlf nvarchar(2)

select
    @width=80,
    @sep=isnull(@sep,'|'),
    @crlf=crlf
from fn__sym()

if not @opt is null
    begin
    select @opt=dbo.fn__str_quote(@opt,'|')
    if charindex('|132|',@opt)>0 select @width=132
    end

select @n=max(len(token))+1 from dbo.fn__str_table(@list,@sep)
select @ll=(@width/@n*@n)+2
-- select * from dbo.fn__str_table('a,b,c',',')
select @ret =coalesce(@ret+@sep,'')+left(token+replicate(' ',@n),@n)
            +case when (pos+1)%(@width/(@n+1))=0 then @crlf else '  ' end
from dbo.fn__str_table(@list,@sep)

return @ret

end -- proc fn__str_flow