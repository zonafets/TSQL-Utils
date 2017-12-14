/*  leave this
    l:see LICENSE file
    g:utility
    v:081212\S.Zaglio: swap two varaibles
    t:begin declare @a sysname,@b sysname set @a='a' set @b='b' exec sp__str_swap @a out,@b out print @a print @b end
*/
CREATE  proc sp__str_swap @a nvarchar(4000) out,@b nvarchar(4000) out
as
begin
declare @t nvarchar(4000)
set @t=@a set @a=@b set @b=@t
end