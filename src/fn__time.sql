/*  leave this
    l:see LICENSE file
    g:utility
    k:time
    v:111215\s.zaglio: when hour is ss.000, 126 strip to ss
    v:111004\s.zaglio: return a float with time of datetime. decimals as ms
    t:select dbo.fn__time(getdate())
*/
CREATE function fn__time(@dt datetime)
returns float
as
begin
declare @f float,@s varchar(32)
select @s=right(convert(varchar(32),@dt,114),12)
select @f=convert(float,replace(left(@s,8),':','')+'.'+right(@s,3))
return @f
end -- fn__time