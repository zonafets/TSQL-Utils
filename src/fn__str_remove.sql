/*  LEAVE THIS
    l:see LICENSE file
    g:utility
    v:081110\S.Zaglio: expanded @seps to nvarchar(32)
    v:080730\S.Zaglio: remove words from group
    t:print dbo.fn__str_remove('a|b|c','a','|') -->b|c
    t:print dbo.fn__str_remove('a|b|c','a|c','|') -->b
    t:print dbo.fn__str_remove('a|b|c','d','|') -->a|b|c
    t:print isnull(dbo.fn__str_remove('a|b|c','a|b|c','|'),'(null)') -->''
*/
CREATE function fn__str_remove(@tokens nvarchar(4000), @remove nvarchar(4000),@sep nvarchar(32)='|')
returns nvarchar(4000)
as
begin
/*
declare @tokens nvarchar(4000)
declare @remove nvarchar(4000)
declare @sep nvarchar(8) set @sep='|'
set @tokens='a|b|c'
set @remove='a'
*/
declare @n int
declare @r nvarchar(4000) set @r=''
declare @i int
declare @k int
declare @token sysname
set @n=dbo.fn__str_count(@tokens,@sep)

set @i=1

while (@i<=@n) begin
    set @token=dbo.fn__str_at(@tokens,@sep,@i)
    set @k=dbo.fn__at(@token,@remove,@sep)
    if @k=0 begin
        if @r<>'' set @r=@r+@sep
        set @r=@r+@token
    end -- if
    set @i=@i+1
end -- while

return @r
end -- function