/*  leave this
    l:see LICENSE file
    g:utility
    v:100511\s.zaglio: normalize a guid to become a table name
    t:print '##'+dbo.fn__str_guid(newid())
*/
create function fn__str_guid(@gid uniqueidentifier)
returns sysname
as
begin
declare @s sysname
select @s=replace(convert(sysname,@gid),'-','')
return @s
end -- fn__str_guid