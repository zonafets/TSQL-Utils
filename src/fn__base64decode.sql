/*  leave this
    l:see LICENSE file
    g:utility
    v:120123\s.zaglio: convert a nvarchar with base 64 to text
    t:select dbo.fn__base64decode('VABlAHMAdAAgAEQAYQB0AGEA') -- Test Data
*/
CREATE function dbo.fn__base64decode
(
    @base64 nvarchar(max)
)
returns nvarchar(max)
as
begin
    declare @bin nvarchar(max)
    select @bin=
    cast(cast(N'' as xml).value(
            'xs:base64Binary(sql:variable("@base64"))',
            'varbinary(max)')
         as nvarchar(max))

    return @bin
end  -- fn__base64decode