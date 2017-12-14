/*  leave this
    l:see LICENSE file
    g:utility
    v:130612.1000\s.zaglio: addapted to fn__prints
    v:130611\s.zaglio: extended 8< macro
    v:130107\s.zaglio: added 8< macro comment
    v:120921\s.zaglio: added @p1,...
    v:110329\s.zaglio: added use of |
    v:100723\s.zaglio: print a separator for better code reading
    t:sp__prints 'errors|help|8<|8<test|8<long test'
*/
CREATE proc sp__prints
    @comment nvarchar(4000)=null,
    @p1 sql_variant=null,
    @p2 sql_variant=null,
    @p3 sql_variant=null,
    @p4 sql_variant=null
as
begin
set nocount on
declare @proc sysname,  @ret int
select @proc=object_name(@@procid), @ret=0

if @comment is null goto help

declare @line nvarchar(80)

if left(@comment,2)='8<'
    begin
    select @line=dbo.fn__prints(@comment,@p1,@p2,@p3,@p4)
    raiserror(@line,10,1)
    goto ret
    end

declare cs cursor local for
    select token
    from fn__str_table(@comment,'|')
    where 1=1
open cs
while 1=1
    begin
    fetch next from cs into @comment
    if @@fetch_status!=0 break

    select @line=dbo.fn__prints(@comment,@p1,@p2,@p3,@p4)
    raiserror(@line,10,1)

    end -- while of cursor
close cs
deallocate cs

goto ret

help:
-- sp__prints 'max len of comment is 76'
exec sp__usage @proc,'
Scope
    print a separator for better code read

Parameters
    @comment    the comment to use as separator
                - can use multiple comments, separated by |
                - accept macro 8< to print scissor line
    @p1,...     replaces %s, %d as in printf

Examples
    sp__prints ''max len of comment is 76''
-- ================================================= max len of comment is 76 ==
'

select @ret=-1
ret:
return @ret
end -- proc sp__prints