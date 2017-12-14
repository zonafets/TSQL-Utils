/*  leave this
    l:see LICENSE file
    g:utility,script
    v:120731\s.zaglio: list cols info; used by sp__script...
    t:select * from fn__script_col(default) order by tablename,tableowner,columnid
*/
create function fn__script_col(@tbl_id int)
returns table
return
select top 100 percent
         sysobjects.name                                                   as tablename,
         sysusers.name                                                     as tableowner,
         c.name                                                            as columnname,
         c.colid                                                           as columnid,
         st.name                                                           as typename,
         case
           when bt.name in (N'nchar',N'nvarchar')
           then c.length / 2
           else c.length
         end as length,
         columnproperty(c.id,c.name,N'precisioN')                          as [precision],
         columnproperty(c.id,c.name,N'scale')                              as scale,
         convert(bit,columnproperty(c.id,c.name,N'isidentity'))            as [identity],
         bt.name                                                           as basetypename,
         convert(bit,c.iscomputed)                                         as iscomputed,
         convert(bit,columnproperty(c.id,c.name,N'isidnotforrepl'))        as notforreplication,
         convert(bit,columnproperty(c.id,c.name,N'allowsnull'))            as allownulls,
         case
           when (columnproperty(c.id,c.name,N'isidentity') <> 0)
           then cast(ident_seed('[' + sysusers.name + '].[' + sysobjects.name + ']') as decimal(38))
           else cast(0 as decimal(38))
         end as identityseed,
         case
           when (columnproperty(c.id,c.name,N'isidentity') <> 0)
           then ident_incr('[' + sysusers.name + '].[' + sysobjects.name + ']')
           else 0
         end as identityincrement,
         case
           when (objectproperty(c.cdefault,N'isdefaultcnst') <> 0)
           then null
           else user_name(d.uid) + N'.' + d.name
         end as defaultname,
         c.cdefault                                                        as defaulttextid,
         user_name(st.uid)                                                 as typeowner,
         user_name(r.uid) + N'.' + r.name                                  as rulename,
         case
           when (objectproperty(c.cdefault,N'isdefaultcnst') <> 0)
           then object_name(c.cdefault)
           else null
         end as dridefaultname,
         c.cdefault                                                        as defaultid,
         df.[text]                                                         as dridefaultcode,
         convert(bit,columnproperty(c.id,c.name,N'isfulltextindexed'))     as fulltextindexed,
         cc.text                                                           as computedtext,
         convert(bit,columnproperty(sysobjects.id,c.name,N'isrowguidcol')) as isrowguidcol,
         c.collation                                                       as collation,
         c.language                                                        as fulltextlanguage,
         ftjoin.name                                                       as fulltexttypecolumn
from     dbo.syscolumns c with (nolock)
         inner join dbo.systypes st
           on st.xusertype = c.xusertype
         inner join dbo.systypes bt with (nolock)
           on bt.xusertype = c.xtype
         inner join dbo.sysobjects with (nolock)
           on sysobjects.id = c.id
         left join dbo.sysusers with (nolock)
           on sysusers.uid = sysobjects.uid
         left join dbo.sysobjects d with (nolock)
           on d.id = c.cdefault
         left join dbo.sysobjects r with (nolock)
           on r.id = c.domain
         left join dbo.syscomments cc with (nolock)
           on cc.id = sysobjects.id
              and cc.number = c.colid
         left join (select ftdep.id,
                           ftdep.number,
                           ftcol2.name
                    from   sysdepends ftdep
                           left join syscolumns ftcol2
                             on ftcol2.colid = ftdep.depnumber
                    where  columnproperty(ftdep.id,ftcol2.name,'istypeforfulltextblob') = 1
                           and ftdep.id = ftdep.depid
                           and ftdep.id = ftcol2.id) ftjoin
           on ftjoin.id = c.id
              and ftjoin.number = c.colid
              and ftjoin.id = c.id
         left join dbo.syscomments df with (nolock)
           on df.id=c.cdefault
where    objectproperty(c.id,'istable') = 1
         and objectproperty(c.id,'issystemtable') = 0
         and (@tbl_id is null or c.id=@tbl_id)
-- end fn__script_col