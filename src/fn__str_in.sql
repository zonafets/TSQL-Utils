/*  leave this
    l:see LICENSE file
    g:utility
    v:100306\s.zaglio: added match char by char if @sep=''
    v:090610\S.Zaglio: match a seached list with a gived list
    t:print dbo.fn__str_in('a,d','a,b,c,d',',') --> 1
    t:print dbo.fn__str_in('a,e','a,b,c,d',',') --> 0
    t:print dbo.fn__str_in(null,'a,b,c,d',',')  --> null
    t:print dbo.fn__str_in('ab','abcd','') --> 1
    t:print dbo.fn__str_in('ae','abcd','') --> 0
*/
CREATE function fn__str_in(
    @searched nvarchar(4000), @tokens nvarchar(4000),@sep nvarchar(32)='|'
    )
returns bit
as
begin
declare @i int,@n int,@r bit
if @sep=''
    begin
    select @n=len(@searched),@i=1
    while (@i<=@n)
        begin
        if charindex(substring(@searched,@i,1),@tokens)=0 return 0
        select @i=@i+1
        end
    select @r=1
    end
else
    begin
    select @n=count(*) from dbo.fn__str_table(@searched,@sep)
    select @i=count(*)
        from dbo.fn__str_table(@tokens,@sep) t
        inner join dbo.fn__str_table(@searched,@sep) s
        on t.token=s.token
    if @i=@n select @r=1 else select @r=0
    end
return @r
end -- fn__str_in