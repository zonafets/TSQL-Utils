/*  leave this
    l:see LICENSE file
    g:utility
    v:131123\s.zaglio: added default exclusion of charset&collation
    v:130730.1154,130729\s.zaglio: see comments into code
    v:130709\s.zaglio: changed to use hash
    v:130406\s.zaglio: added sign of jobs
    v:120821\s.zaglio: added sign of views
    v:120730\s.zaglio: added @detail 4 for sign of pure struct, without names
    v:120517\s.zaglio: removed core group
    v:120516\s.zaglio: return a checksum sign of current db object
    d:120516\s.zaglio: fn__crc32_table
    t:sp__script_sign_test
    t:select dbo.fn__script_sign('fn__sysobjects',1)
    t:select dbo.fn__script_sign('fn__script_sign',1)
*/
CREATE function fn__script_sign(@obj sysname = null,@detail tinyint = null)
returns numeric(14,4)
as
begin
declare
    @xtype varchar(2),@ver numeric(14,4),@obj_id int,
    @src nvarchar(max),@n int

select
    @obj_id=object_id(@obj),@detail=isnull(@detail,0),@src=''

-- details for non jobs:
-- bit_val  meaning
-- 0/null   table columns or params of sp/fn, without defaults
-- 1        table columns with index or params of sp/fn with body
-- 2        table columns or params of sp/fn without names, without defaults
-- 4        table columns with index or params of sp/fn without names
-- details for jobs:
-- bit_val  meaning
-- 0/null   names/status of jobs
-- 1        names/status of jobs with names,commands,flags,outfile of steps
-- 2        status of jobs
-- 6        status of jobs with commands,flags,outfile of steps without names
if left(@obj,2)!='j:'
    begin
    select @xtype=xtype from sysobjects where id=@obj_id
    if @xtype is null return null
    if @xtype in ('U','V')
        begin
        select @src=@src+txt+char(13)
        from (
            select
                case when @detail&4=4 then '' else column_name+'|' end+
                cast(ordinal_position as varchar)+'|'+
                isnull(column_default,'')+'|'+is_nullable+'|'+data_type+'|'+
                isnull(cast(character_maximum_length as varchar),'')+'|'+
                isnull(cast(character_octet_length as varchar),'')+'|'+
                isnull(cast(numeric_precision as varchar),'')+'|'+
                isnull(cast(numeric_precision_radix as varchar),'')+'|'+
                isnull(cast(numeric_scale  as varchar),'')+'|'+
                isnull(cast(datetime_precision  as varchar),'')+'|'+
                case when @detail&8=0 then ''
                     else isnull(character_set_name,'')+'|'+
                          isnull(collation_name,'')
                end
                as txt
            -- select top 100 *
            from information_schema.columns with (nolock)
            where table_name=@obj
            ) tbl
        if @detail&1=1
        select @src=@src+txt+char(13)
        from (
            select
                -- consider only structure, not the position on ownership
                -- [filegroup]+'|'+
                case when @detail&4=4 then '' else parentname+'|' end+
                -- parentowner+'|'+
                case when @detail&4=4 then '' else indexname+'|'+columnname+'|' end+
                cast(descending as char)+'|'+cast(is_included_column as char)+'|'+
                cast([clustered] as char)+'|'+cast([unique] as char)+'|'+
                cast(uniqueconstraint as char)+'|'+cast([primary] as char)+
                cast([norecompute] as char)+'|'+cast(ignoredupkey as char)
                as txt,
                ord as ord
            from (
                -- declare @tbl sysname select @tbl='log_ddl'
                select
                       sysfilegroups.groupname                                                    as [filegroup],
                       sysobjects.name                                                            as parentname,
                       sysusers.name                                                              as parentowner,
                       sysindexes.name                                                            as indexname,
                       syscolumns.name                                                            as columnname,
                       convert(bit,isnull(indexkey_property(syscolumns.id,sysindexkeys.indid,keyno,'isdescending'),
                                          0))                                                     as descending,
                       convert(bit,0)                                                             as is_included_column,
                       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isclustered'))   as [clustered],
                       convert(bit,indexproperty(sysindexes.id,sysindexes.name,N'isunique'))      as [unique],
                       convert(bit,case
                                     when (sysindexes.status & 4096) = 0
                                     then 0
                                     else 1
                                   end) as uniqueconstraint,
                       convert(bit,case
                                     when (sysindexes.status & 2048) = 0
                                     then 0
                                     else 1
                                   end) as [primary],
                       convert(bit,case
                                     when (sysindexes.status & 0x1000000) = 0
                                     then 0
                                     else 1
                                   end) as [norecompute],
                       convert(bit,case
                                     when (sysindexes.status & 0x1) = 0
                                     then 0
                                     else 1
                                   end) as ignoredupkey,
                       sysindexes.name+'|'+right('00000'+cast(sysindexkeys.keyno as varchar),5) as ord
                from     sysindexes with (nolock)                       -- select * from sysindexes where name='ix_log_ddl'
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
                where    (objectproperty(sysindexes.id,'istable') = 1
                           or objectproperty(sysindexes.id,'isview') = 1)
                         and objectproperty(sysindexes.id,'issystemtable') = 0
                         and indexproperty(sysindexes.id,sysindexes.name,N'isautostatistics') = 0
                         and indexproperty(sysindexes.id,sysindexes.name,N'ishypothetical') = 0
                         and sysindexes.name is not null
                         and sysobjects.name=@obj
                ) cols
            ) tbl
        end -- table sign
    else    -- if job
        begin
        if @detail&1=0
            select @src=@src+txt+char(13)
            from (
                select
                    case when @detail&4=0 then specific_schema+'|' else '' end+
                    cast(ordinal_position as varchar)+'|'+
                    parameter_mode+'|'+
                    case when @detail&4=0 then parameter_name+'|' else '' end+
                    data_type+'|'+
                    isnull(cast(character_maximum_length as varchar),'')+'|'+
                    isnull(cast(character_octet_length as varchar),'')+'|'+
                    isnull(cast(numeric_precision as varchar),'')+'|'+
                    isnull(cast(numeric_precision_radix as varchar),'')+'|'+
                    isnull(cast(numeric_scale  as varchar),'')+'|'+
                    isnull(cast(datetime_precision  as varchar),'')+'|'+
                    isnull(character_set_name,'')+'|'+isnull(collation_name,'')
                    as txt
                -- select top 100 *
                from information_schema.parameters with (nolock)
                where specific_name=@obj
                ) tbl
        else
            begin
            select top 1 @src=left(definition,4000)
            from sys.sql_modules with (nolock)
            where object_id=@obj_id
            declare @p1 int,@p2 int, @p3 int
            select @p1=patindex('%[vr]:%',@src)
            if @p1>0
                begin
                select @src=substring(@src,@p1+2,128),@p1=1
                select @p2=patindex('%[,\]%',@src)
                select @src=substring(@src,@p1,@p2-@p1)
                select @ver=cast(@src as numeric(10,4))
                end
            end
        end -- any other obj
    end -- non jobs

else

    begin
    -- select dbo.fn__script_sign('j:%',default) -- tested&verified
    -- select dbo.fn__script_sign('j:%',2) -- tested&verified
    -- select dbo.fn__script_sign('j:%',1) -- tested&verified
    -- select dbo.fn__script_sign('j:%',6) -- tested
    select @obj=substring(@obj,3,128)
    select @src=@src+txt+char(13)
    from (
        select
            case when @detail&2!=2 then name+'|' else '' end+
            cast(enabled as char(1)) as txt
        from msdb..sysjobs
        where name like @obj
        -- nb: the order do not influence the result
        ) jobs

    if @detail&1=1 or @detail&4=4
        select @src=@src+txt+char(13)
        from (
            select top 100 percent
                len(command) lcmd,
                case when @detail&4!=4 then step_name+'|' else '' end+
                command+'|'+cast(flags as nvarchar(5))+'|'+
                isnull(output_file_name,'') as txt
            from msdb..sysjobs j
            join msdb..sysjobsteps js on j.job_id=js.job_id
            where j.name like @obj
            ) jobs

    end -- jobs

/* 130730: it looks like source code is different from case and case, so
           the source hash is not correct with the effect that destination
           is continously recompiled; so I converted sign of vi/fn/sp
           back to get first r/v tag and the rest is returned as crc32
           that fit the numeric integer part of version                       */

if @ver is null
    begin
    declare @chk int select @chk=0
    ;with a as (select 1 as n union all select 1) -- 2
         ,b as (select 1 as n from a ,a a1)       -- 4
         ,c as (select 1 as n from b ,b b1)       -- 16
         ,d as (select 1 as n from c ,c c1)       -- 256
         ,e as (select 1 as n from d ,d d1)       -- 65,536
         ,f as (select 1 as n from e ,e e1)       -- 4,294,967,296=17+trillion chrs
         ,factored as (select row_number() over (order by n) rn from f)
         ,factors as (select rn,(rn*4000)+1 factor from factored)

    select @chk = @chk ^
                 checksum(
                    substring(
                        cast(@src as varbinary(max)),
                        factor - 4000,
                        4000
                        )
                    )
    from factors
    where rn <= ceiling(datalength(cast(@src as varbinary(max)))/(4000.0))
    select @ver=@chk
    end

return @ver
end -- fn__script_sign