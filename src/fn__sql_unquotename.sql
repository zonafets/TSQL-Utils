/*  leave this
    l:see LICENSE file
    g:utility
    v:090914\s.zaglio: revisited using parsename to manage composed names
    v:080505\S.Zaglio: remove bounds [ & ] if exists
    t:print dbo.fn__sql_unquotename('[dbo].[test]')
    t:print dbo.fn__sql_unquotename('[test]')
*/
CREATE function [dbo].[fn__sql_unquotename](
    @name sysname
)
returns sysname
as
begin
select @name=coalesce(parsename(@name,4)+'.','')+coalesce(parsename(@name,3)+'.','')+coalesce(parsename(@name,2)+'.','')+parsename(@name,1)
-- if left(@name,1)='[' and right(@name,1)=']' set @name=substring(@name,2,len(@name)-2)
return @name
end -- function