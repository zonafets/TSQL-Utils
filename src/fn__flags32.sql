/*  leave this
    l:see LICENSE file
    g:obj,utility
    v:120404\s.zaglio: convert a,b,c,... into power of 2
    t:select dbo.fn__flags32('A'),dbo.fn__flags32('AB'),dbo.fn__flags32('Z')
    t:select cast(dbo.fn__flags32('AZ') as binary(4)),dbo.fn__flags32('AZ')
*/
CREATE function fn__flags32(@flags nvarchar(32))
returns int
as
begin
declare @ret int,@i int,@l int,@asc int, @asc_a int,@asc_z int
if isnumeric(@flags)=1 return convert(int,@flags)
select
    @ret=0,@i=1,
    @l=len(@flags),
    @asc_a=ascii('A'),
    @asc_z=ascii('Z')-@asc_a,
    @flags=upper(@flags)

while (@i<=@l)
    begin
    select @asc=ascii(substring(@flags,@i,1))-@asc_a
    if @asc=@asc_z select @ret=~@ret
    else select @ret=@ret|power(2,@asc)
    select @i=@i+1
    end
return @ret
end -- fn__flags32