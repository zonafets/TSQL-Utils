/*  leave this
    l:see LICENSE file
    g:utility
    v:110422\s.zaglio: used by sp__md5 or fn__md5
*/
create function [dbo].[fn__md5_r](@r SMALLINT, @a bigint, @b bigint, @c bigint, @d bigint, @x bigint, @s bigint, @t bigint )
returns bigint
as
begin
declare @r0 bigint, @r1 bigint

if @r=0 begin
    select @r0 = ( ( ( @c ^ @d ) & @b ) ^ @d )
    select @r1 = ( @a + @r0 + @x + @t ) & 0x000000000ffffffff
    select @r0 = ( ( @r1 * @s ) | cast( @r1 * @s / 4294967296 as bigint ) + @b ) & 0x000000000ffffffff
end
if @r=1 begin
    select @r0 = ( ( @b ^ @c ) & @d ) ^ @c
    select @r1 = ( @a + @r0 + @x + @t ) & 0x000000000ffffffff
    select @r0 = ( ( @r1 * @s ) | cast( @r1 * @s / 4294967296 as bigint ) + @b ) & 0x000000000ffffffff
end
if @r=2 begin
    select @r0 = @b ^ @c ^ @d
    select @r1 = ( @a + @r0 + @x + @t ) & 0x00000000ffffffff
    select @r0 = ( ( @r1 * @s ) | cast( @r1 * @s / 4294967296 as bigint ) + @b ) & 0x00000000ffffffff
end
if @r=3 begin
    select @r0 = ( ( ~@d ) | @b ) ^@c
    select @r1 = ( @a + @r0 + @x + @t ) & 0x00000000ffffffff
    select @r0 = ( ( @r1 * @s ) | cast( @r1 * @s / 4294967296 as bigint ) + @b ) & 0x00000000ffffffff
end
return  @r0
end -- fn__md5_r