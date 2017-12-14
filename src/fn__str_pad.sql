/*  leave this
    l:see LICENSE file
    g:utility
    v:130523\s.zaglio: changed tag d of fn__pad to o
    v:091126\s.zaglio: renamed from fn__pad
    v:091027\s.zaglio: added @sep
    v:090611\s.Zaglio: align ntext and pad it
    o:130523\s.zaglio: fn__pad
    t:print dbo.fn__str_pad('test',10,null,null,null)+'|---'
    t:print dbo.fn__str_pad(1234,10,null,null,null)+'|---'
*/
CREATE function fn__str_pad(
    @src sql_variant,
    @width int,
    @sep nchar(1),
    @align tinyint,
    @decimals int
    )
returns nvarchar(4000)
as
begin
declare @s nvarchar(4000)
declare @n real, @num bit
select @s=convert(nvarchar(4000),@src,126)
if @align is null or @align=0
    if isnumeric(@s)=1 select @align=1,@sep=coalesce(@sep,'0')
    else select @align=0,@sep=coalesce(@sep,' ')
if @sep is null select @sep=' '

if @align=0 select @s=left(@s+replicate(@sep,@width),@width)
if @align=1 select @s=right(replicate(@sep,@width)+@s,@width)
-- todo: align=1 rigth
-- todo: align=2 center
-- todo: decimal management
return @s
end -- fn__str_pad