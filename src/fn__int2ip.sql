/*  leave this
    l:see LICENSE file
    g:utility
    k:ip,int,convert
    v:120904\s.zaglio:from http://www.mssqltips.com/sqlservertip/2535/
    t:print dbo.fn__int2ip(167772161) -- 10.0.0.1
*/
CREATE function fn__int2ip(@ip bigint)
returns varchar(15)
as
begin
declare @octet1 tinyint
declare @octet2 tinyint
declare @octet3 tinyint
declare @octet4 tinyint
declare @restofip bigint
set @octet1 = @ip / 16777216
set @restofip = @ip - (@octet1 * 16777216)
set @octet2 = @restofip / 65536
set @restofip = @restofip - (@octet2 * 65536)
set @octet3 = @restofip / 256
set @octet4 = @restofip - (@octet3 * 256)
return(
    convert(varchar, @octet1) + '.' +
    convert(varchar, @octet2) + '.' +
    convert(varchar, @octet3) + '.' +
    convert(varchar, @octet4)
    )
end -- fn__int2ip