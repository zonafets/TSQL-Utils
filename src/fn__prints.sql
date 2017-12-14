/*  leave this
    l:see LICENSE file
    g:utility
    k:prints,sp__prints,separator,better,code,read
    v:130612\s.zaglio: used by sp__prints
    t:select dbo.fn__prints('8<test',default,default,default,default)
    t:select dbo.fn__prints('test',default,default,default,default)
*/
CREATE function fn__prints(
    @comment nvarchar(4000)=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null
    )
returns nvarchar(4000)
as
begin
if @comment is null return null

declare @line nvarchar(80)

if left(@comment,2)='8<'
    begin
    select @line='-- -- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --8<-- -- -- -- -- --'
    select @comment=substring(@comment,3,128)
    if @comment!='' select @line=left(@line,80-len(@comment)-4)+' '+@comment+' --'
    return @line
    end

select @comment=dbo.fn__printf(@comment,@p1,@p2,@p3,@p4,null,null,null,null,null,null)
select @line=replicate('=',76)
select @line='-- ='+replicate('=',72-len(@comment))+' '+@comment+' =='
return @line

end -- fn__prints