/*    leave this
    l:see LICENSE file
    g:utility
    v:100228\s.zaglio: test @s with parts of @likes separated by |
    t:print dbo.fn__inlike('me','you|me|us')    --> 1
    t:print dbo.fn__inlike('it','you|me|us')    --> 0
    t:print dbo.fn__inlike('you','your|%me%|us')    --> 0
*/
create function fn__inlike(@s nvarchar(4000),@likes nvarchar(4000))
returns bit
as
begin
/*
declare @s nvarchar(4000),@likes nvarchar(4000)
select @s='b',@likes='a|b|c'
--*/
declare @like nvarchar(4000),@i int,@n int,@noperc bit
if charindex('%',@s)=0 select @noperc=1
select @i=1,@n=dbo.fn__str_count(@likes,'|')
while (@i<=@n)
    begin
    select @like=dbo.fn__str_at(@likes,'|',@i)
    if @noperc=1 select @like='%'+@like+'%'
    if @s like @like return 1
    select @i=@i+1
    end
return 0
end -- fn__inlike