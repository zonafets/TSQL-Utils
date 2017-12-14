/*
    leave this
    l:see LICENSE file
    g:utility
    v:100228\s.zaglio: count occurrence of @seq in @s
    todo:deprecate to fn__occurrences
    t:print dbo.fn__occurrence('',',')          --> 0
    t:print dbo.fn__occurrence('a,b,c',',')     --> 2
    t:print dbo.fn__occurrence('a',',')         --> 0
    t:print dbo.fn__occurrence('a,b',',')       --> 1
*/
CREATE function [dbo].[fn__occurrence](@s nvarchar(4000),@seq nvarchar(32))
returns int
as
begin
    declare @i int set @i=0
    declare @n int set @n=0
    if @s is null return null
    if @s='' return 0
    declare @k int set @k=len(@seq)
    select @i=charindex(@seq,@s)
    while @i>0
        begin
        select @n=@n+1
        select @i=charindex(@seq,@s,@i+@k)
        end -- while
    return @n
end -- fn__occurrence