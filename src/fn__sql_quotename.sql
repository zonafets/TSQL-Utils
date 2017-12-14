/*  leave this
    l:see LICENSE file
    g:utility
    v:080505\S.Zaglio: add bounds [ & ] if not exists
*/
create function fn__sql_quotename(
    @name sysname
)
returns sysname
as
begin
if left(@name,1)<>'[' and right(@name,1)<>']' set @name=quotename(@name)
return @name
end -- function