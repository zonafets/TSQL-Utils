/*  leave this
    l:see LICENSE file
    g:utility
    v:100328\s.zaglio: return a table with id
    v:100204\s.zaglio: return schema of a table
    t:print dbo.fn__schema_of('fn__schema_of')
*/
create function [dbo].[fn__schema_of](@table sysname)
returns @t table ([name] sysname,id int)
as
begin
-- sp__find 'fn__schema_of' -> fn__comment_types,sp__script
declare @schema sysname
insert @t
select u.name,u.uid
from sysobjects o
join sysusers u on o.uid=u.uid
where o.id=object_id(@table)
return
end -- fn__schema_of