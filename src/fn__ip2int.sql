/*  leave this
    l:see LICENSE file
    g:utility
    k:ip,int,convert
    v:120904\s.zaglio:from http://www.mssqltips.com/sqlservertip/2535/
    t:print dbo.fn__ip2int('10.0.0.1')
*/
create function fn__ip2int(@ip varchar(15))
returns bigint  -- for future ipv6
as
begin
return(
convert(bigint, parsename(@ip,1)) +
convert(bigint, parsename(@ip,2)) * 256 +
convert(bigint, parsename(@ip,3)) * 65536 +
convert(bigint, parsename(@ip,4)) * 16777216
)
end -- fn__int2ip