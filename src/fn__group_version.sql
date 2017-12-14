/*  leave this
    l:see LICENSE file
    g:utility
    k:script,version,group
    v:120802.1100\s.zaglio: return last version of a group
    t:select dbo.fn__group_version('utility') -- 4 secs reduced to 2
*/
CREATE function fn__group_version(@grp sysname)
returns sysname
as
begin
declare @t table(id int,tag char,val sysname,primary key(id,tag))
insert @t(id,tag,val)
select obj_id,tag,val1 from fn__script_info(default,'rvg',0) a
where not tag is null

select @grp=max(a.val)
from @t a join @t b on a.id=b.id and a.tag!='g' and b.tag='g'

return @grp
end -- fn__group_version