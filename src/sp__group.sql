/*  leave this
    l:see LICENSE file
    g:utility
    v:090507.1000\s.zaglio: stored of example
    t:sp__group 'utility','sp__group'
*/
CREATE proc sp__group
    @group sysname=null,
    @objs sysname=null, --- objs to add
    @order int=null,
    @parent sysname=null,
    @chk sysname=null,
    @dbg bit=0
as
begin
set nocount on
declare @r int
raiserror('todo and rethinking',18,1)
end -- proc