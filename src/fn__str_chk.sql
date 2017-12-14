/*  leave this
    l:see LICENSE file
    g:utility
    v:121004\s.zaglio: renamed into fn__str_chk
    d:121004\s.zaglio: fn__chk_str
    v:110219\s.zaglio: check if a string contain only specified chars
    t:print dbo.fn__chk_str('correct_me@email.it','a-z|0-9|_.@;') -- ok
    t:print dbo.fn__chk_str('correct_me@email.it,me@svr','a-z|0-9|_.;') -- bad
*/
create function fn__str_chk(@str nvarchar(4000),@chars nvarchar(4000))
returns bit
as
begin
/*
declare @str nvarchar(4000),@chars nvarchar(4000)
select @str='k@;k',@chars='a-z|@_'
-- print dbo.fn__str_quote('a|b','|')
*/
declare @tkn sysname,@c nchar(1),@i int,@l int,@ok bit
select  @chars=dbo.fn__str_unquote(@chars,'|'),
        @l=len(@str),@i=1

declare cs cursor local for
    select '['+token+']'
    from dbo.fn__str_table(@chars,'|')
while (@i<=@l)
    begin
    select @ok=0,@c=substring(@str,@i,1)
    open cs
    while 1=1
        begin
        fetch next from cs into @tkn
        if @@fetch_status!=0 break
        if @c like @tkn select @ok=1
        -- exec sp__printf 'c(%s) tkn(%s) ok(%d)',@c,@tkn,@ok
        end
    close cs
    if @ok=0 return 0
    select @i=@i+1
    end

deallocate cs

return 1
end -- fn__chk_str