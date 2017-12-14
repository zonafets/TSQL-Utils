/*
    leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: added sep '' for ' '
    v:100228\s.zaglio: optimized with use of charindex
    v:091018\s.zaglio: replaced datalenght(@sep) with len coz unicode problem
    v:081212\S.Zaglio: replaced len(@sep) with datalenght
    v:081130\S.Zaglio: optimization & corrected a bug
    v:081110\S.Zaglio: expanded @seps to nvarchar(32)
    v:080926\S.Zaglio: added null & '' cases
    v:080721\S.Zaglio: count tokens
    t:print dbo.fn__str_count('a|b|c','|')  --> 3
    t:print dbo.fn__str_count('a|b|','|')   --> 3  (ex 2)
    t:print dbo.fn__str_count('a','|')      --> 1
    t:print dbo.fn__str_count('','|')       --> 0
    t:print dbo.fn__str_count(null,'|')     --> null
    t:print dbo.fn__str_count('a b c d','')
*/
CREATE function [dbo].[fn__str_count](@tokens nvarchar(4000),@sep nvarchar(32)='|')
returns int
as
begin
    declare @i int set @i=0
    declare @n int set @n=0
    if @tokens is null return null
    if @tokens='' return 0
    if @sep='' select @tokens=replace(@tokens,' ','|'),@sep='|'
    declare @k int set @k=len(@sep)
    declare @l int set @l=len(@tokens)
    select @i=charindex(@sep,@tokens)
    while @i>0
        begin
        select @n=@n+1
        select @i=charindex(@sep,@tokens,@i+@k)
        end -- while
/*  old:
    while @i<=@l begin
        if substring(@tokens,@i,@k)=@sep set @n=@n+1
        set @i=@i+1
    end -- while
*/
    return @n+1
end -- fn__str_count