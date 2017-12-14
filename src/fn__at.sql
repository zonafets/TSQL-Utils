/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: added null control: nb: problem on ' ', see tests
    v:090211/S.Zaglio: optimized
    v:081110.0100/S.Zaglio: expanded @seps to nvarchar(32)
    v:080801/S.Zaglio: managed bug on tokens count and added @sep
    v:080730/S.Zaglio: managed bug on empty strings
    v:080714/S.Zaglio: return token position into tokens: b(a|b|c) -> 2
    t:print dbo.fn__at('a','a|b|c','|') print dbo.fn__at('d','a|b|c','|')  -->1 & 0
    t:print dbo.fn__at('a','b','|') -->0
    t:print dbo.fn__at('a','','|') -->0
    t:print dbo.fn__at('a b c','b','') -->0   -- NB! infinite loop
    t:print dbo.fn__at('','a|b|c','|') -->0
    t:print isnull(dbo.fn__str_at('a|b|c','|',4),'(null)') -->null
    t:print isnull(dbo.fn__str_at('a','|',3),'(null)') --> null
    t:print isnull(dbo.fn__str_at('a|','|',3),'(null)') -->null
    c:very slow. Must be optimized
*/
CREATE function fn__at(
    @token sysname,
    @tokens nvarchar(4000),
    @sep nvarchar(32)='|'
    )
returns int
as
begin
declare @i int
if not @tokens is null
    select @i=pos from dbo.fn__str_table(@tokens,@sep) where token=@token
return coalesce(@i,0)
/*
-- old version
declare @n int
declare @st sysname
set @i=1
set @n=dbo.fn__str_count(@tokens,@sep)
while (@i<=@n) begin
    set @st=dbo.fn__str_at(@tokens,@sep,@i)
    if @st=@token return @i
    if @st is null break
    set @i=@i+1
end -- while
return 0
*/
end -- fn__at