/*  leave this
    l:see LICENSE file
    g:utility
    k:index,optimization,statistic
    v:111116.1040\s.zaglio: use mssql perf. sp to list indexes to add
*/
CREATE proc sp__maint_idxstats
    @obj sysname = null
as
begin
declare @proc sysname,@ret int
select @proc=object_name(@@procid),@ret=0
if @obj is null goto help

declare @db sysname,@sql nvarchar(max)
select @db=db_name()

if @obj='#' select @obj=null

-- Find missing indices on your server
select
    parsename(statement,3) db,
    parsename(statement,1) obj,
    equality_columns+isnull(','+inequality_columns,''),
    'create index '
    +upper(replace(
        'idx_perf_'
        + case when equality_columns is null then ltrim('') else  replace(rtrim(ltrim(replace(replace(replace(equality_columns,',','_'),'[',''),']',''))),char(32), '_')  end
        + case when inequality_columns is null then ltrim('') else replace(rtrim(ltrim(replace(replace(replace(inequality_columns,',','_'),'[',''),']',''))),char(32), '_') end
        + '_'+cast(mid.index_handle as varchar)
        ,'__','_'))
    + ' on ' + statement + ' ('
    + case when equality_columns is null then '' else  replace(replace(equality_columns,'[',''),']','') end
    + case when inequality_columns is null then ')' else '' end
    + case when inequality_columns is null then '' else + (case when equality_columns is null then '' else  ',' end) + inequality_columns + ')' end
    + case when included_columns is null then '' else + ' include(' + replace(replace(included_columns,'[',''),']','') + ')'end
from sys.dm_db_missing_index_details mid
inner join sys.dm_db_missing_index_groups mig on mig.index_handle = mid.index_handle
inner join sys.dm_db_missing_index_group_stats migs on mig.index_group_handle = migs.group_handle
where (@obj is null or @obj=parsename(statement,1))
order by
    parsename(statement,3),parsename(statement,1),
    avg_total_user_cost * avg_user_impact * (user_seeks + user_scans) desc;


--- Find unused indices in your database
select @sql = 'use ' + quotename(@db)
select @sql = @sql + ';
select distinct
    object_name(sis.object_id) tablename,
    si.name as indexname,
    sc.name as columnname,
    sic.index_id,
    sis.user_seeks,
    sis.user_scans,
    sis.user_lookups,
    sis.user_updates
from sys.dm_db_index_usage_stats sis
inner join sys.indexes si
    on sis.object_id = si.object_id
    and sis.index_id = si.index_id
    and (si.is_disabled = 0
    and si.is_primary_key=0)
inner join sys.index_columns sic
    on sis.object_id = sic.object_id
    and sic.index_id = si.index_id
inner join sys.columns sc
    on sis.object_id = sc.object_id
    and sic.column_id = sc.column_id
where
    sis.database_id = db_id(@db)
    and (user_seeks = 0 and user_scans=0 and user_lookups=0)
    and  si.type=2 and si.is_unique = 0 and si.is_primary_key = 0 and is_disabled = 0
    and (@obj is null or @obj=object_name(sis.object_id))
order by tablename
'
exec sp_executesql @sql,N'@db sysname, @obj sysname',@db=@db,@obj=@obj
goto ret

help:
exec sp__usage @proc,'
Scope
    use mssql perf. sp to list indexes to add

Parameters
    @obj    object to filter for indexes or # for all
'

ret:
return @ret
end -- sp__maint_idxstats