/*  leave this
    l:see LICENSE file
    g:utility,script
    v:121005\s.zaglio: done previous
    v:121004\s.zaglio: a bug near included columns
    v:120802\s.zaglio: added more column info and index_id
    v:120731\s.zaglio: adapted to mssql 2k5
    v:120305\s.zaglio: list indexes info (used by sp__script..)
    t:select * from fn__script_idx(object_id('cfg'))
*/
CREATE function fn__script_idx(@tbl_id int=null)
returns table
as
return
select
       sysindexes.id                                                              as [object_id],
       sysindexes.indid                                                           as index_id,
       six.index_column_id                                                        as index_column_id,
       sysindexkeys.keyno                                                         as keyno,
       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isclustered'))   as [clustered],
       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isunique'))      as [unique],
       convert(bit,case
                     when (sysindexes.status & 4096) = 0
                     then 0
                     else 1
                   end)                                                           as uniqueconstraint,
       convert(bit,case
                     when (sysindexes.status & 2048) = 0
                     then 0
                     else 1
                   end)                                                           as [primary],
       convert(bit,case
                     when (sysindexes.status & 0x1000000) = 0
                     then 0
                     else 1
                   end)                                                           as norecompute,
       convert(bit,case
                     when (sysindexes.status & 0x1) = 0
                     then 0
                     else 1
                   end)                                                           as ignoredupkey,
       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'ispadindex'))    as ispadindex,
       convert(bit,objectproperty(sysindexes.id,N'istable'))                      as istable,
       convert(bit,objectproperty(sysindexes.id,N'isview'))                       as isview,
       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isfulltextkey')) as fulltextkey,
       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isstatistics'))  as [statistics],
       sysfilegroups.groupname                                                    as filegroup,
       sysobjects.name                                                            as parentname,
       sysusers.name                                                              as parentowner,
       sysindexes.name                                                            as indexname,
       sysindexes.origfillfactor                                                  as [fillfactor],
       sysindexes.status,
       syscolumns.name                                                            as columnname,
       syscolumns.xusertype                                                       as columnxusertype,
       systypes.name                                                              as columntype,
       convert(bit,isnull(indexkey_property(syscolumns.id,sysindexkeys.indid,keyno,'isdescending'),
                          0))                                                     as descending,
       isnull(six.is_included_column,0)                                           as is_included_column

from    sysindexes with (nolock)                       -- select * from sysindexes where name='ix_log_ddl'
        inner join sysindexkeys with (nolock)          -- select * from sysindexkeys where indid=2 and id=2103730597
           on sysindexes.indid = sysindexkeys.indid     -- select * from sys.indexes where name='ix_log_ddl'
              and sysindexkeys.id = sysindexes.id       -- select * from sys.indexkeys where indid=2 and id=2103730597
        inner join syscolumns with (nolock)            -- select * from syscolumns where id=2103730597 and colid in (1,6,12,4)
           on syscolumns.colid = sysindexkeys.colid     -- select * from sys.index_columns where object_id=2103730597 and index_id=2
              and syscolumns.id = sysindexes.id
        inner join sysobjects with (nolock)
           on sysobjects.id = sysindexes.id
        left join sysusers with (nolock)
           on sysusers.uid = sysobjects.uid
        left join sysfilegroups with (nolock)
           on sysfilegroups.groupid = sysindexes.groupid
        join sys.index_columns six
            on sysindexes.id  = six.[object_id]
            and sysindexes.indid  = six.[index_id]
            and sysindexkeys.keyno = six.key_ordinal
            and sysindexkeys.colid = six.column_id
            -- and six.is_included_column=1
        join systypes
            on syscolumns.xusertype=systypes.xusertype
where    (objectproperty(sysindexes.id,'istable') = 1
           or objectproperty(sysindexes.id,'isview') = 1)
         and objectproperty(sysindexes.id,'issystemtable') = 0
         and indexproperty(sysindexes.id,sysindexes.name,N'isautostatistics') = 0
         and indexproperty(sysindexes.id,sysindexes.name,N'ishypothetical') = 0
         and sysindexes.name is not null
         and (@tbl_id is null or sysobjects.id=@tbl_id)
-- fn__script_idx