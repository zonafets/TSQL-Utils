/*  leave this
    l:see LICENSE file
    g:utility
    v:130228\s.zaglio: convert a hex string to binary
    t:select dbo.fn__hex2bin('01234ab') -- return null
    t:select dbo.fn__hex2bin('0x1234ab') -- return 0x1234AB
    t:select dbo.fn__hex2bin('1234ab') -- return 0x1234AB
*/
CREATE function fn__hex2bin(
    @hex varchar(max)
)
returns varbinary(max)
as
begin
   return(select cast('' as xml).value('xs:hexBinary( substring(sql:variable("@hex"), sql:column("t.pos")) )', 'varbinary(max)')
   from (select case substring(@hex, 1, 2) when '0x' then 3 else 0 end) as t(pos))
end -- fn__hex2bin