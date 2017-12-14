/*  leave this
    l:see LICENSE file
    g:utility
    v:100917\s.zaglio: print a rules for text imports
    t:sp__ruler 120
*/
create proc sp__ruler
    @len    int=0,
    @start  int=1
as
begin
set nocount on
-- if @dbg>=@@nestlevel exec sp__printf 'write here the error msg'
declare @proc sysname,  @ret int -- standard API: 0=OK -1=HELP, any=error id
select @proc='sp__ruler', @ret=0

if @len is null or @len<11 or @len>4000 goto help

declare @r1 nvarchar(4000),@r2 nvarchar(4000)
select @r1='-- ',@r2='-- '
while (@start<=@len)
    begin
    select @r2=@r2+case when @start%10=0 then '.' else convert(nchar(1),@start%10) end
    if @start%10=0 select @r1=@r1+right('          '+convert(nvarchar(4),@start),10)
    select @start=@start+1
    end -- while

print @r1 print @r2
goto ret

help:
exec sp__usage @proc,'
Scope
    print a ruler of len @len for text imports

Example

--         10        20
-- 12345678901234567890
'
select @ret=-1

ret:
return @ret
end -- sp__ruler