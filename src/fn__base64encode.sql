/*  leave this
    l:see LICENSE file
    g:utility
    v:120123\s.zaglio: convert a nvarchar to base 64 code
    t:select dbo.fn__base64encode('Test Data') -- VABlAHMAdAAgAEQAYQB0AGEA
*/
CREATE function dbo.fn__base64encode
(
    @text nvarchar(max)
)
returns nvarchar(max)
as
begin
    declare @bin varchar(max)
    select @bin=
        cast(N'' as xml).value(
                'xs:base64Binary(xs:hexBinary(sql:column("bin")))',
                'VARCHAR(MAX)'
             )
    from (select cast(@text as varbinary(max)) as bin) as tmp;
    return @bin
end  -- fn__base64encode