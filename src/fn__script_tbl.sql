/*  leave this
    l:see LICENSE file
    g:utility,script
    v:120731\s.zaglio: list tbls info; used by sp__script...
    t:select * from fn__script_tbl(default)
*/
CREATE function fn__script_tbl(@tbl_id int)
returns table
return
select
       o.name,
       user_name(o.uid)                                                as owner,
       o.id,
       convert(bit,objectproperty(o.id,'tablehasactivefulltextindex')) as fulltextindexed,
       sysfulltextcatalogs.name                                        as fulltextcatalogname,
       sysfilegroups.groupname                                         as filegroup,
       (select top 1 groupname
        from   sysfilegroups
               inner join sysindexes
                 on sysindexes.groupid = sysfilegroups.groupid
        where  sysindexes.indid = 255
               and sysindexes.id = o.id)                               as textfilegroup
from     dbo.sysobjects o with (nolock)
         left join sysfulltextcatalogs with (nolock)
           on sysfulltextcatalogs.ftcatid = o.ftcatid
         left join sysindexes with (nolock)
           on sysindexes.id = o.id
         left join sysfilegroups with (nolock)
           on sysfilegroups.groupid = sysindexes.groupid
where    objectproperty(o.id,N'istable') = 1
         and objectproperty(o.id,N'ismsshipped') = 0
         and objectproperty(o.id,N'issystemtable') = 0
         and objectproperty(o.id,N'tableisfake') = 0
         and sysindexes.indid < 2
         and (@tbl_id is null or o.id=@tbl_id)
-- end fn__script_tbl