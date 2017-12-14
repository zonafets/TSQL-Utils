/*  leave this
    l:see LICENSE file
    g:utility
    v:120116\s.zaglio: fast row cnt. function version of sp__count
    t:select dbo.fn__count('cfg')
*/
CREATE function fn__count(@tbl sysname)
returns bigint
as
begin
declare @n bigint
--SQL Server 2000+ (work well also in 2k5)
SELECT @n= si.rowcnt
FROM sysindexes si
JOIN sysobjects so ON si.id = so.id
WHERE si.indid < 2  --clustered index or heap
AND OBJECTPROPERTY(so.id, 'IsMSShipped') = 0
AND so.xtype='u'
and so.name=@tbl

/* SQL Server 2005+  give also schema
-- originally from
-- http://developerspla.net/2010/sql-server/tsql/row-count-of-all-tables/
SELECT [TableName]  = OBJECT_SCHEMA_NAME(sp.[object_id]) + '.'
                    + OBJECT_NAME(sp.[object_id])
            ,[RowCount]     = SUM(sp.rows)
FROM        sys.partitions sp
WHERE       OBJECT_SCHEMA_NAME(sp.[object_id]) <> 'sys'
AND         sp.index_id < 2
GROUP BY    object_id
ORDER BY    [RowCount] DESC
*/
return @n
end -- fn__count