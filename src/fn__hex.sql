/*  leave this
    l:see LICENSE file
    g:utility
    c:http://blogs.msdn.com/b/sqltips/archive/2008/07/02/converting-from-hex-string-to-varbinary-and-vice-versa.aspx
    v:130929\s.zaglio: sys.fn_varbintohexstr is too slow with big data
    v:130707\s.zaglio: added alias tag
    v:100805\s.zaglio: managed null @value
    v:091018\s.zaglio: convert a binary value into a hex string
    t:
        declare @s sysname set @s='hello world!!'+char(13)+char(10)
        print dbo.fn__hex(convert(varbinary(128),@s))
        0x680065006c006c006f00200077006f0072006c006400210021000d000a00
*/
CREATE function [dbo].[fn__hex] (
    @value varbinary(max)
    )
returns varchar(max)
as
begin
return '0x' +
       cast('' as xml).value('xs:hexBinary(sql:variable("@value") )',
                             'varchar(max)');
end -- fn__hex