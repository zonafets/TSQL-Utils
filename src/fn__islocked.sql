/*  leave this
    l:see LICENSE file
    g:utility
    v:091018\s.zaglio: added @db_id  (sp__find 'fn__islocked')
    v:090910\s.zaglio: check if an object is locked
    t:print dbo.fn__islocked(db_id('msdb'),object_id('sysobjects'))
*/
CREATE function [dbo].[fn__islocked](@id int,@db_id int)
returns bit
as
begin
declare @locked bit
select @locked=0
if exists(
    -- sp_lock
    select     null
        /*convert (smallint, req_spid) As spid,
        rsc_dbid As dbid,
        rsc_objid As ObjId,
        rsc_indid As IndId,
        substring (v.name, 1, 4) As Type,
        substring (rsc_text, 1, 16) as Resource,
        substring (u.name, 1, 8) As Mode,
        substring (x.name, 1, 5) As Status
        */
    from
        master.dbo.syslockinfo,
        master.dbo.spt_values v,
        master.dbo.spt_values x,
        master.dbo.spt_values u
    where
        rsc_dbid=@db_id and
        rsc_objid=@id and
        master.dbo.syslockinfo.rsc_type = v.number
        and v.type = 'LR'
        and master.dbo.syslockinfo.req_status = x.number
        and x.type = 'LS'
        and master.dbo.syslockinfo.req_mode + 1 = u.number
        and u.type = 'L'
    /*order by spid*/     )     select @locked=1 return @locked end -- function