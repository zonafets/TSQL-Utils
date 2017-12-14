/*  leave this
    l:see LICENSE file
    g:utility
    v:100919\s.zaglio: compilable in mssql2k but not executable
    v:100228\s.zaglio: added obj_id and null on @table
    v:100204\s.zaglio: return comment of obj
    t:
        create table test_info
            (
            a nchar(10) null,
            b nchar(10) null
            )  on [primary]
        exec sp__comment 'test_info','table comment'
        execute sp_addextendedproperty
            N'ms_description', N'description col a',
            N'schema', N'dbo', N'table', N'test_info', N'column', N'a'

        select * from dbo.fn__comments('test_info')

        drop table test_info
*/
CREATE function [dbo].[fn__comments](@table sysname)
returns @t table(obj_id int,column_name sysname null,value nvarchar(4000) null)
as
begin
declare @id int select @id=object_id(@table)
-- select top 10 * from syscolumns
if dbo.fn__isMSSQL2K()=1
    insert @t(obj_id,column_name,value)
    select id,col,com from (
        select      o.id id,
                    o.name as col,
                    convert(nvarchar(4000),p.value) as com,
                    0 as ord
        from    sysobjects o
        join    sysproperties p
                    on o.id = p.id
                    and 0 = p.smallid
        where       p.name='MS_Description'
        and         @table is null or o.id=@id

        union

        select      o.id id,
                    c.name as col,
                    convert(nvarchar(4000),p.value) as com,
                    c.colorder as ord
        from    sysobjects o
        join    sysproperties p
                    on o.id = p.id
        join    syscolumns c
                    on p.smallid = c.colid
                    and p.id = c.id
        where       p.name='MS_Description'
        and         @table is null or o.id=@id
    ) qry
    order by ord
else
    insert @t
    select id,col,com from (
        select      o.object_id id, null as col,
                    convert(nvarchar(4000),ep.value) as com,
                    0 as ord
        from        sys.objects o
        join        sys.extended_properties ep
                    on o.object_id = ep.major_id and 0=ep.minor_id
        join        sys.schemas s
                    on o.schema_id = s.schema_id
        where       ep.name='MS_Description'
        and         @table is null or o.object_id=@id

        union

        select      o.object_id id, c.name as col,
                    convert(nvarchar(4000),ep.value) as com,
                    c.colorder as ord
        from        sys.objects o
        join        sys.extended_properties ep
                    on o.object_id = ep.major_id
        join        sys.schemas s
                    on o.schema_id = s.schema_id
        join        syscolumns c
                    on ep.minor_id = c.colid
                    and ep.major_id = c.id
        where       ep.name='MS_Description'
        and         @table is null or o.object_id=@id
    ) qry
    order by ord
return
/*
SQLSERVER 2000:

SELECT    sysobjects.Name AS ObjectName,
            sysobjects.xtype AS ObjectType,
            user_name(sysobjects.uid) AS SchemaOwner,
            sysproperties.name AS PropertyName,
            sysproperties.value AS PropertyValue,
            syscolumns.name AS ColumnName,
            syscolumns.colid AS Ordinal
FROM    sysobjects INNER JOIN sysproperties
            ON sysobjects.id = sysproperties.id
            LEFT JOIN syscolumns
            ON sysproperties.smallid = syscolumns.colid
            AND sysproperties.id = syscolumns.id
ORDER BY SchemaOwner, ObjectName, ObjectType, Ordinal

SQLSERVER 2005:
SELECT        o.Name AS ObjectName,
            o.type AS ObjectType,
            s.name AS SchemaOwner,
            ep.name AS PropertyName,
            ep.value AS PropertyValue,
            c.name AS ColumnName,
            c.colid AS Ordinal
FROM        sys.objects o INNER JOIN sys.extended_properties ep
            ON o.object_id = ep.major_id
            INNER JOIN sys.schemas s
            ON o.schema_id = s.schema_id
            LEFT JOIN syscolumns c
            ON ep.minor_id = c.colid
            AND ep.major_id = c.id
WHERE        o.type IN ('V', 'U', 'P')
ORDER BY    SchemaOwner,ObjectName, ObjectType, Ordinal
*/
end -- function