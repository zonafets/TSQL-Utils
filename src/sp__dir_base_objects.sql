/*  leave this
    l:see LICENSE file
    g:utility
    v:090124\S.Zaglio: list objects grouped by roots
*/
create proc sp__dir_base_objects
as
select a,b,c from
(
 select
    o.name,dbo.fn__str_at(o.name,'__',1)+'_' as a,
    dbo.fn__str_at(dbo.fn__str_at(o.name,'__',2),'_',1) as b,
    coalesce(dbo.fn__str_at(dbo.fn__str_at(o.name,'__',2),'_',2),'') as c
 from sysobjects o
 where o.xtype in ('P','FN','U','V') and left(o.name,3)!='dt_' -- and left(o.name,4)='fn__'
) a
group by a,b,c
having c!=''
union
select a,b,c from
(
 select
    o.name,
    dbo.fn__str_at(o.name,'_',1) as a,
    substring(o.name,len(dbo.fn__str_at(o.name,'_',1))+2,4000) as b,
    '' as c
 from sysobjects o
 where o.xtype in ('P','FN','U','V') and left(o.name,3)!='dt_' and not o.name like '%[_][_]%'
) a
group by a,b,c
--having c!=''
order by a,b,c