/*  leave this
    l:see LICENSE file
    g:utility
    v:091227\s.zaglio: added %idx% (not for multi)
    v:081110\S.Zaglio: expanded @seps to nvarchar(32)
    v:081011\S.Zaglio: added @@ marker for multiple replace
    v:080814\S.Zaglio: generalized separator
    v:080729\S.Zaglio: repeat expression with %% replacing it with tokens or repleace multiple @@
    t:print dbo.fn__str_exp('dst.%%=src.%%','a|b|c',', ') --> dst.a=src.a,dst.b=src.b,...
    t:print dbo.fn__str_exp('dst.@@ and src.@@','a|b|c','|')  --> dst.a and src.b  || MULTI
    t:print dbo.fn__str_exp('%%=''@@''','a,b,c',',') --> a='@@',b='@@',c='@@'
    t:print dbo.fn__str_exp('''%%'' [%idx%]','a,b,c',',') --> 'a' [1],'b' [2],'c' [3]
*/
CREATE function [dbo].[fn__str_exp](
    @expression nvarchar(4000),
    @tokens nvarchar(4000),
    @sep nvarchar(32)
)
returns nvarchar(4000)
as
begin
declare @r nvarchar(4000) select @r=''
declare @n int,@i int,@k int,@l int
declare @multi bit select @multi=0
declare @stri sysname,@ri bit
if @sep is null return null
set @n=dbo.fn__str_count(@tokens,'%%')
--return dbo.fn__printf('%d',@n,null,null,null,null,null,null,null,null,null)
select @ri=case when charindex('%idx%',@expression)>0 then 1 else 0 end
set @k=charindex('%%',@expression)
if @k=0 begin
    set @k=charindex('@@',@expression)
    if @k>0 begin set @multi=1 set @l=len(@expression) end else set @k=1
end
set @n=dbo.fn__str_count(@tokens,dbo.fn__trim(@sep))
set @i=1
while (@i<=@n and @k>0)
    begin
    if @multi=0
        begin
        if @ri=1
            begin
            select @stri=convert(sysname,@i)
            set @r=@r+replace(replace(@expression,'%idx%',@stri),'%%',
                dbo.fn__str_at(@tokens,dbo.fn__trim(@sep),@i))
            end
        else
            set @r=@r+replace(@expression,'%%',dbo.fn__str_at(@tokens,dbo.fn__trim(@sep),@i))
        end
    else
        begin
        set @expression=substring(@expression,1,@k-1)+ dbo.fn__str_at(@tokens,dbo.fn__trim(@sep),@i)+substring(@expression,@k+2,@l)
        set @k=charindex('@@',@expression,1)
        end
    if @i<@n select @r=@r+@sep
    set @i=@i+1
end -- while
if @multi=0 return @r
return @expression
end -- fn__str_exp