/*  leave this
    l:see LICENSE file
    g:utility
    v:100404\s.zaglio: print tokens tabbed
    t:sp__str_print 'one,two,longname,first_name,last_name,this is a sentence,test 1234'
                    ,',',@indent='    '
                    ,@out='#src'
*/
create proc sp__str_print
    @objs nvarchar(4000),@sep nvarchar(32)='|',
    @indent sysname='',
    @out sysname=null,
    @len int=80
as
begin
set nocount on
declare @n int,@ll int,@txt nvarchar(4000),@k int,@crlf nvarchar(2)

select @crlf=crlf from dbo.fn__sym()

declare @tkns table(pos int,token sysname,sep nvarchar(32))
insert @tkns select pos,token,@sep from dbo.fn__str_table(@objs,@sep)

select @len=@len-len(@indent)
select @n=max(len(token))+1,@k=max(pos) from @tkns
select @txt=null,@ll=((@len/@n*@n)+2)

update @tkns set sep='' where pos=@k

select @txt =coalesce(@txt,@indent)+left(token+sep+replicate(' ',@n),@n)
            +case when pos%(@len/@n)=0 then @crlf+@indent else '  ' end
from @tkns
order by pos

if @out is null
    print @txt
else
    begin
    select @txt='insert '+@out+' select '''+replace(@txt,'''','''''')+''''
    exec(@txt)
    end

end -- sp__str_print