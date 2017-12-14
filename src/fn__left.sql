/*  leave this
    l:see LICENSE file
    g:utility
    v:081010\S.Zaglio: extend left with negative len
    t:print dbo.fn__left('without last char*',-1) -->without last char
*/
create function fn__left(@s nvarchar(4000),@l smallint)
returns nvarchar(4000)
as
begin
declare @s1 nvarchar(4000)
if @s is null return null
if @l=0 return ''
if @l>0 set @s1=left(@s,@l)
else set @s1=left(@s,len(@s)+@l)
return @s1
end -- function