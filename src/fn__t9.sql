/*  leave this
    l:see LICENSE file
    g:utility
    v:090609\S.Zaglio: adapted to sqlce
    v:061226\S.Zaglio: get like expression on keys pressed
    t:print dbo.fn__t9('cod','.1234567890')
*/
CREATE function [dbo].[fn__t9](@fld sysname, @t9 nvarchar(32))
returns nvarchar(4000)
as
begin
/*
    select top 5 * from table where 1=1 -- search for t9:23
    and (cod like 'a%' or cod like 'b%' or cod like 'c%' or cod like '2%')
    and (cod like '_d%' or cod like '_e%' or cod like '_f%' or cod like '_3%')
    and ...
*/
declare @r nvarchar(4000) set @r=''
declare @c nchar(1)
declare @s sysname,@chars sysname
declare @i int, @j int , @l int
select @i=1,@l=len(@t9)
while (@i<=@l)
    begin
    select @r=@r+case @i when @l then ' and ((' else ' and (' end
    select @c=substring(@t9,@i,1)
    select @j=@i-1,@s=''
    while (@j>0) select @s=@s+N'_',@j=@j-1
    set @chars =
        case @c
        when '0' then '0'
        when '1' then '1'
        when '2' then 'cba2'
        when '3' then 'fed3'
        when '4' then 'ihg4'
        when '5' then 'lkj5'
        when '6' then 'onm6'
        when '7' then 'srqp7'
        when '8' then 'vut8'
        when '9' then 'zyxw9'
        else '_'
        end -- case
    select @j=len(@chars)
    while (@j>0)
        begin
        select @r=@r+@fld+' like '''+@s+substring(@chars,@j,1)+'%''',@j=@j-1
        if @j>0 select @r=@r+' or '
        end
    set @r=@r+')'
    set @i=@i+1
    end -- while i<len(t9)
set @r=@r+')'
return @r
end -- function t9